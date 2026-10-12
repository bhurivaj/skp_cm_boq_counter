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
    const isLoggingIn = ref(false);
    const showSettings = ref(false);
    const showStockRequestModal = ref(false);

    // Authentication
    const authToken = ref(null);
    const authUsername = ref('');
    const credentials = ref({ username: '', password: '' });

    // Settings
    const settings = ref({
      apiBaseUrl: 'https://odoo.catice.co',
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

    // Load settings and credentials on mount
    onMounted(() => {
      if (window.sketchup && window.sketchup.load_settings) {
        window.sketchup.load_settings('');
      }
      if (window.sketchup && window.sketchup.load_credentials) {
        window.sketchup.load_credentials('');
      }
      const defaultDate = new Date();
      defaultDate.setDate(defaultDate.getDate() + settings.value.expectedDays);
      stockRequest.value.dueDate = defaultDate.toISOString().slice(0, 10);
      stockRequest.value.projectName = projectNumber.value;
    });

    window.loadedSettings = (config) => {
      if (config.api_base_url) settings.value.apiBaseUrl = config.api_base_url;
      if (config.expected_days_offset) settings.value.expectedDays = config.expected_days_offset;
    };

    window.loadedCredentials = (creds) => {
      if (creds.username) {
        credentials.value.username = creds.username;
        credentials.value.password = creds.password;
      }
    };

    window.settingsSaved = (success) => {
      showToast(success ? 'Settings saved successfully!' : 'Failed to save settings', success ? 'success' : 'error');
    };

    window.credentialsSaved = (success, message) => {
      showToast(success ? 'Credentials saved!' : (message || 'Failed to save credentials'), success ? 'success' : 'error');
    };

    window.credentialsCleared = (success) => {
      showToast(success ? 'Logged out successfully' : 'Failed to clear credentials', success ? 'info' : 'error');
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
        api_base_url: settings.value.apiBaseUrl,
        expected_days_offset: settings.value.expectedDays
      };

      if (window.sketchup && window.sketchup.save_settings) {
        window.sketchup.save_settings(new URLSearchParams(config).toString());
      }
    };

    const login = async (username, password) => {
      try {
        const formData = new FormData();
        formData.append('username', username);
        formData.append('password', password);

        const response = await fetch(`${settings.value.apiBaseUrl}/auth/login/access-token`, {
          method: 'POST',
          body: formData
        });

        if (!response.ok) throw new Error('Login failed: ' + response.status);

        const result = await response.json();
        authToken.value = result.access_token;
        authUsername.value = username;
        await loadLocations();
        return { success: true };
      } catch (error) {
        return { success: false, error: error.message };
      }
    };

    const saveAndLogin = async () => {
      if (!credentials.value.username || !credentials.value.password) {
        showToast('Please enter username and password', 'error');
        return;
      }
      isLoggingIn.value = true;

      const params = new URLSearchParams({
        username: credentials.value.username,
        password: credentials.value.password
      }).toString();

      if (window.sketchup && window.sketchup.save_credentials) {
        window.sketchup.save_credentials(params);
      }

      const result = await login(credentials.value.username, credentials.value.password);
      isLoggingIn.value = false;
      showToast(result.success ? 'Logged in successfully!' : ('Login failed: ' + result.error), result.success ? 'success' : 'error');
    };

    const testLogin = async () => {
      if (!credentials.value.username || !credentials.value.password) {
        showToast('Please enter username and password', 'error');
        return;
      }
      isLoggingIn.value = true;
      const result = await login(credentials.value.username, credentials.value.password);
      isLoggingIn.value = false;
      if (result.success) {
        showToast('Login test successful!', 'success');
        authToken.value = null;
      } else {
        showToast('Login test failed: ' + result.error, 'error');
      }
    };

    const logout = () => {
      authToken.value = null;
      authUsername.value = '';
      locations.value = [];
      if (window.sketchup && window.sketchup.clear_credentials) {
        window.sketchup.clear_credentials('');
      }
    };

    const loadLocations = async () => {
      if (!authToken.value) return;
      try {
        const response = await fetch(`${settings.value.apiBaseUrl}/locations/`, {
          headers: { 'Authorization': `Bearer ${authToken.value}` }
        });
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
      if (!authToken.value) {
        const result = await login(credentials.value.username, credentials.value.password);
        if (!result.success) {
          showToast('Please login first', 'error');
          return;
        }
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

        const response = await fetch(`${settings.value.apiBaseUrl}/stock-requests/`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${authToken.value}`
          },
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
      searchQuery, totalQuantity, isLoading, isLoggingIn, showSettings, showStockRequestModal,
      settings, credentials, authToken, authUsername, stockRequest, locations, toast,
      saveCsv, saveSettings, saveAndLogin, testLogin, logout, loadLocations, sendStockRequest
    };
  }
}).mount('#app');
