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
    const showSettings = ref(false);

    // The account lives in SKP CM Extensions Hub — Ruby sends it via window.authStatus (counter.rb)
    const auth = ref({ hub: false, logged_in: false, username: null, online: false });
    const authHint = computed(() => {
      if (!auth.value.hub) return 'ต้องติดตั้งหรืออัปเดต SKP CM Extensions Hub (0.4.0 ขึ้นไป) แล้ว restart SketchUp';
      if (!auth.value.logged_in) return 'กรุณา login ใน SKP CM Extensions Hub';
      if (!auth.value.online) return 'เชื่อมต่อ server ไม่ได้ (ออฟไลน์)';
      return '';
    });

    // Settings
    const settings = ref({
      expectedDays: 4
    });

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
    });

    window.loadedSettings = (config) => {
      if (config.expected_days_offset) settings.value.expectedDays = config.expected_days_offset;
    };

    // Called by Ruby on open and whenever the Hub logs in/out
    window.authStatus = (status) => {
      auth.value = status;
    };

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

    return { 
      sortedData, filteredData, sortTable, filename, projectNumber, reviseNo, dateUpdated, 
      searchQuery, totalQuantity, showSettings, settings, auth, authHint, toast,
      saveCsv, saveSettings, openHubLogin
    };
  }
}).mount('#app');
