# frozen_string_literal: true

module SkpCm
  module BoQCounter
    module HtmlGenerator
      # Escape JavaScript strings to prevent XSS
      def self.escape_js_string(str)
        str.to_s
           .gsub('\\', '\\\\')
           .gsub("'", "\\'")
           .gsub('"', '\\"')
           .gsub("\n", '\\n')
           .gsub("\r", '\\r')
           .gsub("\t", '\\t')
      end

      def self.generate_html(data, filename, project_number, revise_no, date_modified)
        # Escape all data for safe injection into JavaScript
        table_rows = data.map do |name, count|
          escaped_name = escape_js_string(name)
          "{ name: '#{escaped_name}', count: #{count} }"
        end.join(",")
        
        escaped_filename = escape_js_string(filename)
        escaped_project_number = escape_js_string(project_number)
        escaped_revise_no = escape_js_string(revise_no)
        escaped_date = escape_js_string(date_modified)
        
        <<-HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>BoQ Report - Classmat Suite</title>
          <script src="https://cdn.jsdelivr.net/npm/vue@3/dist/vue.global.prod.js"></script>
          <script src="https://cdn.tailwindcss.com"></script>
          <style>
            .toast {
              position: fixed;
              top: 20px;
              right: 20px;
              padding: 1rem 1.5rem;
              border-radius: 0.5rem;
              color: white;
              font-weight: 500;
              animation: slideIn 0.3s ease-out;
              z-index: 1000;
              box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
            }
            .toast.success { background-color: #10b981; }
            .toast.error { background-color: #ef4444; }
            .toast.info { background-color: #3b82f6; }
            @keyframes slideIn {
              from { transform: translateX(100%); opacity: 0; }
              to { transform: translateX(0); opacity: 1; }
            }
            .loader {
              border: 3px solid #f3f4f6;
              border-top: 3px solid #3b82f6;
              border-radius: 50%;
              width: 20px;
              height: 20px;
              animation: spin 1s linear infinite;
              display: inline-block;
              margin-left: 8px;
            }
            @keyframes spin {
              0% { transform: rotate(0deg); }
              100% { transform: rotate(360deg); }
            }
            .modal-overlay {
              position: fixed;
              inset: 0;
              background-color: rgba(0, 0, 0, 0.5);
              display: flex;
              align-items: center;
              justify-content: center;
              z-index: 50;
            }
            .modal-content {
              background: white;
              padding: 2rem;
              border-radius: 0.5rem;
              max-width: 600px;
              width: 90%;
              max-height: 90vh;
              overflow-y: auto;
              box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
            }
            .badge {
              display: inline-block;
              padding: 0.25rem 0.75rem;
              border-radius: 9999px;
              font-size: 0.75rem;
              font-weight: 600;
            }
            .badge-success { background-color: #d1fae5; color: #065f46; }
            .badge-error { background-color: #fee2e2; color: #991b1b; }
          </style>
        </head>
        <body class="bg-gray-100 p-6">
          <div id="app" class="max-w-6xl mx-auto bg-white p-6 rounded-lg shadow-lg border border-gray-300">
            <!-- Header with Settings and Auth Status -->
            <div class="flex justify-between items-center mb-4">
              <div class="flex items-center gap-4">
                <h2 class="text-2xl font-bold">Bill of Quantities Report</h2>
                <span class="text-xs px-2 py-1 bg-blue-100 text-blue-800 rounded">Classmat Suite</span>
                <span v-if="authToken" class="badge badge-success">
                  🔒 {{ authUsername }}
                </span>
                <span v-else class="badge badge-error">
                  🔓 Not logged in
                </span>
              </div>
              <button @click="showSettings = true" class="p-2 hover:bg-gray-100 rounded-full transition" title="Settings">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path>
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
                </svg>
              </button>
            </div>

            <!-- Project Info -->
            <div class="grid grid-cols-2 gap-4 mb-4 p-4 border border-gray-300 rounded bg-gray-50">
              <div>
                <p><strong>Filename:</strong> {{ filename }}</p>
                <p><strong>Project Number:</strong> {{ projectNumber }}</p>
              </div>
              <div>
                <label class="font-bold">Revise No:</label>
                <input type="text" v-model="reviseNo" class="border border-gray-400 px-2 py-1 rounded w-full mb-2">
                <label class="font-bold">Date Updated:</label>
                <input type="date" v-model="dateUpdated" class="border border-gray-400 px-2 py-1 rounded w-full">
              </div>
            </div>

            <!-- Search and Stats -->
            <div class="flex justify-between items-center mb-4">
              <input 
                type="text" 
                v-model="searchQuery" 
                placeholder="🔍 Search components..." 
                class="border border-gray-400 px-4 py-2 rounded w-96 focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
              <div class="text-sm text-gray-600">
                <span class="font-semibold">Total Items:</span> {{ filteredData.length }} | 
                <span class="font-semibold">Total Qty:</span> {{ totalQuantity }}
              </div>
            </div>

            <!-- Table -->
            <table class="w-full table-auto border-collapse border border-gray-300">
              <thead>
                <tr class="bg-gray-200">
                  <th @click="sortTable('name')" class="border border-gray-300 px-4 py-2 cursor-pointer hover:bg-gray-300 transition">
                    Component Name <span v-if="sortKey === 'name'">{{ sortOrder === 1 ? '▲' : '▼' }}</span>
                  </th>
                  <th @click="sortTable('count')" class="border border-gray-300 px-4 py-2 cursor-pointer hover:bg-gray-300 transition">
                    Quantity <span v-if="sortKey === 'count'">{{ sortOrder === 1 ? '▲' : '▼' }}</span>
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="item in filteredData" :key="item.name" class="hover:bg-gray-100 transition">
                  <td class="border border-gray-300 px-4 py-2">{{ item.name }}</td>
                  <td class="border border-gray-300 px-4 py-2 text-center font-semibold">{{ item.count }}</td>
                </tr>
                <tr v-if="filteredData.length === 0">
                  <td colspan="2" class="border border-gray-300 px-4 py-8 text-center text-gray-500">
                    No components found matching "{{ searchQuery }}"
                  </td>
                </tr>
              </tbody>
            </table>

            <!-- Action Buttons -->
            <div class="flex justify-end mt-4 space-x-2">
              <button @click="saveCsv" class="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded transition">
                Save as CSV
              </button>
              <button 
                @click="showStockRequestModal = true" 
                :disabled="!authToken || isLoading" 
                class="bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded transition disabled:opacity-50 disabled:cursor-not-allowed"
                :title="!authToken ? 'Please login first' : ''"
              >
                Send Stock Request
                <span v-if="isLoading" class="loader"></span>
              </button>
            </div>

            <!-- Settings Modal -->
            <div v-if="showSettings" class="modal-overlay" @click.self="showSettings = false">
              <div class="modal-content">
                <h3 class="text-xl font-bold mb-4">Settings</h3>
                
                <!-- Authentication Section -->
                <div class="mb-6 pb-6 border-b">
                  <h4 class="font-semibold mb-3">Authentication</h4>
                  
                  <div v-if="!authToken">
                    <div class="mb-3">
                      <label class="block font-semibold mb-2">Email/Username:</label>
                      <input 
                        type="email" 
                        v-model="credentials.username" 
                        class="border border-gray-400 px-3 py-2 rounded w-full focus:outline-none focus:ring-2 focus:ring-blue-500"
                        placeholder="user@example.com"
                      >
                    </div>
                    <div class="mb-3">
                      <label class="block font-semibold mb-2">Password:</label>
                      <input 
                        type="password" 
                        v-model="credentials.password" 
                        class="border border-gray-400 px-3 py-2 rounded w-full focus:outline-none focus:ring-2 focus:ring-blue-500"
                        placeholder="••••••••"
                      >
                    </div>
                    <div class="flex gap-2">
                      <button @click="saveAndLogin" :disabled="isLoggingIn" class="bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded transition flex-1 disabled:opacity-50">
                        {{ isLoggingIn ? 'Logging in...' : 'Save & Login' }}
                      </button>
                      <button @click="testLogin" :disabled="isLoggingIn" class="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded transition disabled:opacity-50">
                        Test
                      </button>
                    </div>
                  </div>
                  
                  <div v-else class="flex items-center justify-between">
                    <span class="badge badge-success">Logged in as {{ authUsername }}</span>
                    <button @click="logout" class="bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded transition">
                      Logout
                    </button>
                  </div>
                </div>

                <!-- API Configuration -->
                <div class="mb-4">
                  <h4 class="font-semibold mb-3">API Configuration</h4>
                  <label class="block font-semibold mb-2">Base URL:</label>
                  <input 
                    type="text" 
                    v-model="settings.apiBaseUrl" 
                    class="border border-gray-400 px-3 py-2 rounded w-full focus:outline-none focus:ring-2 focus:ring-blue-500 mb-3"
                    placeholder="https://api.example.com"
                  >
                  
                  <label class="block font-semibold mb-2">Expected Return Days:</label>
                  <input 
                    type="number" 
                    v-model.number="settings.expectedDays" 
                    class="border border-gray-400 px-3 py-2 rounded w-full focus:outline-none focus:ring-2 focus:ring-blue-500"
                    min="1"
                    max="365"
                  >
                </div>

                <div class="flex justify-end space-x-2 mt-4">
                  <button @click="showSettings = false" class="bg-gray-300 hover:bg-gray-400 px-4 py-2 rounded transition">
                    Close
                  </button>
                  <button @click="saveSettings" class="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded transition">
                    Save Settings
                  </button>
                </div>
              </div>
            </div>

            <!-- Stock Request Modal -->
            <div v-if="showStockRequestModal" class="modal-overlay" @click.self="showStockRequestModal = false">
              <div class="modal-content">
                <h3 class="text-xl font-bold mb-4">Stock Request</h3>
                
                <div class="mb-3">
                  <label class="block font-semibold mb-2">Request Type:</label>
                  <select v-model="stockRequest.requestType" class="border border-gray-400 px-3 py-2 rounded w-full focus:outline-none focus:ring-2 focus:ring-blue-500">
                    <option value="issue">Issue (ขอเบิก)</option>
                    <option value="return">Return (คืน)</option>
                    <option value="transfer">Transfer (โอน)</option>
                  </select>
                </div>

                <div class="mb-3">
                  <label class="block font-semibold mb-2">Target Site:</label>
                  <select v-model="stockRequest.targetSiteId" class="border border-gray-400 px-3 py-2 rounded w-full focus:outline-none focus:ring-2 focus:ring-blue-500">
                    <option value="">-- Select Site --</option>
                    <option v-for="site in locations" :key="site.id" :value="site.id">
                      {{ site.name }}
                    </option>
                  </select>
                </div>

                <div class="mb-3">
                  <label class="block font-semibold mb-2">Project Name:</label>
                  <input 
                    type="text" 
                    v-model="stockRequest.projectName" 
                    class="border border-gray-400 px-3 py-2 rounded w-full focus:outline-none focus:ring-2 focus:ring-blue-500"
                    :placeholder="projectNumber"
                  >
                </div>

                <div class="mb-3">
                  <label class="block font-semibold mb-2">Reason/Notes:</label>
                  <textarea 
                    v-model="stockRequest.reason" 
                    class="border border-gray-400 px-3 py-2 rounded w-full focus:outline-none focus:ring-2 focus:ring-blue-500"
                    rows="3"
                    placeholder="เหตุผลในการขอเบิก..."
                  ></textarea>
                </div>

                <div class="mb-3">
                  <label class="block font-semibold mb-2">Due Date:</label>
                  <input 
                    type="date" 
                    v-model="stockRequest.dueDate" 
                    class="border border-gray-400 px-3 py-2 rounded w-full focus:outline-none focus:ring-2 focus:ring-blue-500"
                  >
                </div>

                <div class="mb-3">
                  <label class="block font-semibold mb-2">Status:</label>
                  <select v-model="stockRequest.status" class="border border-gray-400 px-3 py-2 rounded w-full focus:outline-none focus:ring-2 focus:ring-blue-500">
                    <option value="draft">Draft (แบบร่าง)</option>
                    <option value="pending">Pending (รออนุมัติ)</option>
                  </select>
                </div>

                <div class="flex justify-end space-x-2 mt-4">
                  <button @click="showStockRequestModal = false" class="bg-gray-300 hover:bg-gray-400 px-4 py-2 rounded transition">
                    Cancel
                  </button>
                  <button @click="sendStockRequest" :disabled="isLoading" class="bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded transition disabled:opacity-50">
                    {{ isLoading ? 'Sending...' : 'Send Request' }}
                  </button>
                </div>
              </div>
            </div>

            <!-- Toast Notifications -->
            <div v-if="toast.show" :class="['toast', toast.type]">
              {{ toast.message }}
            </div>
          </div>

          <script>
            const { createApp, ref, computed, onMounted } = Vue;
            createApp({
              setup() {
                const data = ref([#{table_rows}]);
                const filename = ref("#{escaped_filename}");
                const projectNumber = ref("#{escaped_project_number}");
                const reviseNo = ref("#{escaped_revise_no}");
                const dateUpdated = ref("#{escaped_date}");
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
          </script>
        </body>
        </html>
        HTML
      end
    end
  end
end
