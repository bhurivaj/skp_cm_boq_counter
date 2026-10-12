const { createApp, ref, computed, onMounted } = Vue;
createApp({
  setup() {
    // window.BOQ_DATA is written by html_generator.rb
    const data = ref(window.BOQ_DATA.rows);
    const filename = ref(window.BOQ_DATA.filename);
    const projectNumber = ref(window.BOQ_DATA.projectNumber);
    const reviseNo = ref(window.BOQ_DATA.reviseNo);
    const dateUpdated = ref(window.BOQ_DATA.dateUpdated);
    const sortKey = ref('name');
    const sortOrder = ref(1);
    const searchQuery = ref('');
    const isLoading = ref(false);
    const showSettings = ref(false);
    const showStockRequestModal = ref(false);

    // The account lives in SKP CM Extensions Hub — Ruby sends it via window.authStatus (counter.rb)
    const auth = ref({ hub: false, logged_in: false, username: null, token: null, api_base_url: null });
    const canSendRequest = computed(() => auth.value.logged_in && !!auth.value.token);
    const authHint = computed(() => {
      if (!auth.value.hub) return 'ต้องติดตั้งหรืออัปเดต SKP CM Extensions Hub (0.4.0 ขึ้นไป) แล้ว restart SketchUp';
      if (!auth.value.logged_in) return 'กรุณา login ใน SKP CM Extensions Hub';
      if (!auth.value.token) return 'เชื่อมต่อ server ไม่ได้ (ออฟไลน์)';
      return '';
    });

    // Settings
    const settings = ref({
      expectedDays: 4
    });

    // Stock Request
    const stockRequest = ref({
      requestType: 'issue',
      projectName: '',
      reason: '',
      targetSiteId: '',
      dueDate: '',
      status: 'draft'
    });

    const locations = ref([]);

    const toast = ref({
      show: false,
      message: '',
      type: 'success'
    });

    // Load settings and the Hub login status on mount
    onMounted(() => {
      if (window.sketchup && window.sketchup.load_settings) {
        window.sketchup.load_settings('');
      }
      if (window.sketchup && window.sketchup.auth_status) {
        window.sketchup.auth_status('');
      }
      const defaultDate = new Date();
      defaultDate.setDate(defaultDate.getDate() + settings.value.expectedDays);
      stockRequest.value.dueDate = defaultDate.toISOString().slice(0, 10);
      stockRequest.value.projectName = projectNumber.value;
    });

    window.loadedSettings = (config) => {
      if (config.expected_days_offset) settings.value.expectedDays = config.expected_days_offset;
    };

    // Called by Ruby on open, after relogin and whenever the Hub logs in/out
    let waitingForAuth = [];
    window.authStatus = (status) => {
      const hadToken = !!auth.value.token;
      auth.value = status;
      if (!status.token) locations.value = [];
      if (status.token && !hadToken) loadLocations();
      const waiting = waitingForAuth;
      waitingForAuth = [];
      waiting.forEach((resolve) => resolve(status));
    };

    // Ask the Hub to log in again; resolves with the next status from Ruby
    const relogin = () => new Promise((resolve) => {
      waitingForAuth.push(resolve);
      try {
        window.sketchup.relogin('');
      } catch (e) {
        waitingForAuth = waitingForAuth.filter((r) => r !== resolve);
        resolve(auth.value);
      }
    });

    window.settingsSaved = (success) => {
      showToast(success ? 'Settings saved successfully!' : 'Failed to save settings', success ? 'success' : 'error');
    };

    const filteredData = computed(() => {
      return sortedData.value.filter(item => 
        item.name.toLowerCase().includes(searchQuery.value.toLowerCase())
      );
    });

    const sortedData = computed(() => {
      return [...data.value].sort((a, b) => {
        let result = 0;
        if (typeof a[sortKey.value] === 'string') {
          result = a[sortKey.value].localeCompare(b[sortKey.value]);
        } else {
          result = a[sortKey.value] - b[sortKey.value];
        }
        return result * sortOrder.value;
      });
    });

    const totalQuantity = computed(() => {
      return filteredData.value.reduce((sum, item) => sum + item.count, 0);
    });

    const sortTable = (key) => {
      if (sortKey.value === key) {
        sortOrder.value *= -1;
      } else {
        sortKey.value = key;
        sortOrder.value = 1;
      }
    };

    const showToast = (message, type = 'success') => {
      toast.value = { show: true, message, type };
      setTimeout(() => { toast.value.show = false; }, 3000);
    };

    const saveCsv = () => {
      const queryParams = new URLSearchParams({
        filename: filename.value,
        projectNumber: projectNumber.value,
        reviseNo: reviseNo.value,
        dateUpdated: dateUpdated.value
      }).toString();

      if (window.sketchup && window.sketchup.save_to_csv) {
        window.sketchup.save_to_csv(queryParams);
      }
    };

    const saveSettings = () => {
      const config = {
        expected_days_offset: settings.value.expectedDays
      };

      if (window.sketchup && window.sketchup.save_settings) {
        window.sketchup.save_settings(new URLSearchParams(config).toString());
      }
    };

    const openHubLogin = () => {
      if (window.sketchup && window.sketchup.open_hub_login) window.sketchup.open_hub_login('');
    };

    // fetch Odoo with the Hub token; on 401 ask the Hub to log in again and retry once
    const apiFetch = async (path, options = {}, retried = false) => {
      const headers = Object.assign({}, options.headers, { 'Authorization': `Bearer ${auth.value.token}` });
      const response = await fetch(`${auth.value.api_base_url}${path}`, Object.assign({}, options, { headers }));
      if (response.status === 401 && !retried) {
        const status = await relogin();
        if (status.token) return apiFetch(path, options, true);
      }
      return response;
    };

    const loadLocations = async () => {
      if (!auth.value.token) return;
      try {
        const response = await apiFetch('/locations/');
        if (!response.ok) throw new Error('Failed to load locations');
        locations.value = await response.json();
      } catch (error) {
        showToast('Failed to load locations: ' + error.message, 'error');
      }
    };

    const sendStockRequest = async () => {
      if (!stockRequest.value.targetSiteId) {
        showToast('Please select a target site', 'error');
        return;
      }
      if (!stockRequest.value.projectName) {
        showToast('Please enter project name', 'error');
        return;
      }
      if (!canSendRequest.value) {
        showToast(authHint.value, 'error');
        return;
      }

      isLoading.value = true;
      try {
        const dueDate = new Date(stockRequest.value.dueDate);
        dueDate.setHours(17, 0, 0, 0);

        const requestBody = {
          request_type: stockRequest.value.requestType,
          project_name: stockRequest.value.projectName,
          reason: stockRequest.value.reason,
          target_site_id: stockRequest.value.targetSiteId,
          due_date: dueDate.toISOString(),
          stock_items: data.value.map(item => ({
            product_id: item.name,
            quantity: item.count
          })),
          asset_items: [],
          status: stockRequest.value.status
        };

        const response = await apiFetch('/stock-requests/', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(requestBody)
        });

        if (!response.ok) throw new Error('Request failed with status ' + response.status);
        showToast('Stock request sent successfully!', 'success');
        showStockRequestModal.value = false;
      } catch (error) {
        showToast('Failed to send request: ' + error.message, 'error');
      } finally {
        isLoading.value = false;
      }
    };

    return { 
      sortedData, filteredData, sortTable, filename, projectNumber, reviseNo, dateUpdated, 
      searchQuery, totalQuantity, isLoading, showSettings, showStockRequestModal,
      settings, auth, canSendRequest, authHint, stockRequest, locations, toast,
      saveCsv, saveSettings, openHubLogin, loadLocations, sendStockRequest
    };
  }
}).mount('#app');
