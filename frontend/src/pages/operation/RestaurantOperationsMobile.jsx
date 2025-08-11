import { useState, useEffect, useMemo, useCallback } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { useToast } from '../../contexts/ToastContext';
import api from '../../services/api';
import '../../styles/mobile-operations.css';
import { 
  Users, 
  Plus, 
  ShoppingCart, 
  Clock,
  Check,
  AlertCircle,
  Package,
  Coffee,
  ChevronRight,
  X,
  Minus,
  RefreshCw,
  Eye,
  Edit3,
  DollarSign,
  Search,
  Filter,
  ChevronDown,
  Home,
  List
} from 'lucide-react';

const RestaurantOperationsMobile = () => {
  const { user } = useAuth();
  const { showToast } = useToast();

  // Main states
  const [tables, setTables] = useState([]);
  const [selectedTable, setSelectedTable] = useState(null);
  const [orders, setOrders] = useState([]);
  const [allOrders, setAllOrders] = useState([]); 
  const [recipes, setRecipes] = useState([]);
  const [containers, setContainers] = useState([]);
  const [groups, setGroups] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [step, setStep] = useState('tables');

  // Cart and menu states
  const [cart, setCart] = useState([]);
  const [selectedGroup, setSelectedGroup] = useState(null);
  const [currentOrder, setCurrentOrder] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [showFilters, setShowFilters] = useState(false);

  // Modal states
  const [selectedOrderDetails, setSelectedOrderDetails] = useState(null);
  const [showFloatingCart, setShowFloatingCart] = useState(false);

  // Load all initial data with better error handling
  const loadInitialData = useCallback(async (showRefreshIndicator = false) => {
    try {
      if (showRefreshIndicator) setRefreshing(true);
      else setLoading(true);

      console.log('🔄 Loading restaurant data...');
      
      const [tablesRes, recipesRes, containersRes, groupsRes, allOrdersRes] = await Promise.all([
        api.get('/tables/'),
        api.get('/recipes/?is_active=true&is_available=true'),
        api.get('/containers/?is_active=true'),
        api.get('/groups/'),
        api.get('/orders/?status=CREATED')
      ]);
      
      console.log('✅ Data loaded:', {
        tables: tablesRes.data?.length || 0,
        recipes: recipesRes.data?.length || 0,
        containers: containersRes.data?.length || 0,
        groups: groupsRes.data?.length || 0,
        orders: allOrdersRes.data?.length || 0
      });

      setTables(Array.isArray(tablesRes.data) ? tablesRes.data : []);
      setRecipes(Array.isArray(recipesRes.data) ? recipesRes.data : []);
      setContainers(Array.isArray(containersRes.data) ? containersRes.data : []);
      setGroups(Array.isArray(groupsRes.data) ? groupsRes.data : []);
      setAllOrders(Array.isArray(allOrdersRes.data) ? allOrdersRes.data : []);
      
    } catch (error) {
      console.error('❌ Error loading data:', error);
      showToast('Error al cargar datos del restaurante', 'error');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [showToast]);

  useEffect(() => {
    loadInitialData();
    // Auto refresh every 30 seconds
    const interval = setInterval(() => loadInitialData(true), 30000);
    return () => clearInterval(interval);
  }, [loadInitialData]);

  // Load orders for specific table
  const loadTableOrders = async (tableId) => {
    try {
      console.log(`🔄 Loading orders for table ${tableId}...`);
      const response = await api.get(`/orders/?table=${tableId}&status=CREATED`);
      const tableOrders = Array.isArray(response.data) ? response.data : [];
      console.log(`✅ Loaded ${tableOrders.length} orders for table ${tableId}`);
      setOrders(tableOrders);
      return tableOrders;
    } catch (error) {
      console.error('❌ Error loading table orders:', error);
      showToast('Error al cargar pedidos de la mesa', 'error');
      return [];
    }
  };

  // Table management functions
  const getTableOrders = useCallback((tableId) => {
    return allOrders.filter(order => order.table?.id === tableId);
  }, [allOrders]);

  const getTableStatus = useCallback((tableId) => {
    const tableOrders = getTableOrders(tableId);
    return tableOrders.length > 0 ? 'occupied' : 'available';
  }, [getTableOrders]);

  const getTableSummary = useCallback((tableId) => {
    const tableOrders = getTableOrders(tableId);
    if (tableOrders.length === 0) return null;

    const totalAmount = tableOrders.reduce((sum, order) => 
      sum + parseFloat(order.grand_total || order.total_amount || 0), 0
    );
    
    const totalItems = tableOrders.reduce((sum, order) => 
      sum + (order.items?.length || 0), 0
    );

    const oldestOrder = tableOrders.reduce((oldest, order) => {
      const orderTime = new Date(order.created_at);
      const oldestTime = new Date(oldest.created_at);
      return orderTime < oldestTime ? order : oldest;
    });

    return {
      orderCount: tableOrders.length,
      totalAmount,
      totalItems,
      duration: getDurationText(oldestOrder.created_at),
      orders: tableOrders
    };
  }, [getTableOrders]);

  const getDurationText = (createdAt) => {
    const now = new Date();
    const created = new Date(createdAt);
    const diffMinutes = Math.floor((now - created) / (1000 * 60));
    
    if (diffMinutes < 60) {
      return `${diffMinutes}m`;
    } else {
      const hours = Math.floor(diffMinutes / 60);
      const minutes = diffMinutes % 60;
      return minutes > 0 ? `${hours}h ${minutes}m` : `${hours}h`;
    }
  };

  // Navigation functions
  const handleTableSelect = async (table) => {
    console.log(`🎯 Selected table: ${table.table_number}`);
    setSelectedTable(table);
    await loadTableOrders(table.id);
    setStep('orders');
  };

  const handleCreateNewOrder = () => {
    console.log('➕ Creating new order');
    setCurrentOrder(null);
    setCart([]);
    setStep('menu');
    setShowFloatingCart(false);
  };

  const handleEditOrder = (order) => {
    console.log(`✏️ Editing order ${order.id}`);
    setCurrentOrder(order);
    const cartItems = order.items?.map(item => ({
      recipe: item.recipe,
      quantity: item.quantity,
      notes: item.notes || '',
      is_takeaway: item.is_takeaway || false,
      unit_price: parseFloat(item.unit_price),
      total_price: parseFloat(item.total_price)
    })) || [];
    setCart(cartItems);
    setStep('menu');
    setShowFloatingCart(true);
  };

  // Cart management functions
  const addToCart = (recipe) => {
    const existingItemIndex = cart.findIndex(item => 
      item.recipe.id === recipe.id && !item.notes && !item.is_takeaway
    );

    if (existingItemIndex >= 0) {
      const newCart = [...cart];
      newCart[existingItemIndex].quantity += 1;
      newCart[existingItemIndex].total_price = newCart[existingItemIndex].unit_price * newCart[existingItemIndex].quantity;
      setCart(newCart);
    } else {
      const newItem = {
        recipe,
        quantity: 1,
        notes: '',
        is_takeaway: false,
        unit_price: parseFloat(recipe.base_price),
        total_price: parseFloat(recipe.base_price)
      };
      setCart([...cart, newItem]);
    }
    setShowFloatingCart(true);
    showToast(`${recipe.name} agregado al carrito`, 'success');
  };

  const updateCartItem = (index, updates) => {
    const newCart = [...cart];
    const oldItem = newCart[index];
    newCart[index] = { ...oldItem, ...updates };
    
    if (updates.quantity !== undefined) {
      newCart[index].total_price = newCart[index].unit_price * updates.quantity;
    }
    
    setCart(newCart);
  };

  const removeFromCart = (index) => {
    const newCart = cart.filter((_, i) => i !== index);
    setCart(newCart);
    if (newCart.length === 0) {
      setShowFloatingCart(false);
    }
    showToast('Item eliminado del carrito', 'info');
  };

  // Price calculation functions
  const getCartTotal = () => {
    return cart.reduce((total, item) => total + parseFloat(item.total_price), 0);
  };

  const getContainerTotal = () => {
    const takeawayItems = cart.filter(item => item.is_takeaway);
    return takeawayItems.reduce((total, item) => {
      const container = containers.find(c => c.id === item.recipe.container);
      return total + (container ? parseFloat(container.price) * item.quantity : 0);
    }, 0);
  };

  const getGrandTotal = () => {
    return getCartTotal() + getContainerTotal();
  };

  // Order saving function with better error handling
  const saveOrder = async () => {
    if (cart.length === 0) {
      showToast('Agregue items al pedido', 'error');
      return;
    }

    try {
      setLoading(true);
      console.log(`💾 Saving order...`, { currentOrder: currentOrder?.id, itemCount: cart.length });
      
      if (currentOrder) {
        // Update existing order - FIXED: Include container sales
        const orderData = {
          items: cart.map(item => ({
            recipe: item.recipe.id,
            quantity: item.quantity,
            notes: item.notes || '',
            is_takeaway: item.is_takeaway || false
          })),
          container_sales: cart
            .filter(item => item.is_takeaway && item.recipe.container)
            .map(item => ({
              container: item.recipe.container,
              quantity: item.quantity
            }))
        };
        
        await api.put(`/orders/${currentOrder.id}/`, orderData);
        showToast('Pedido actualizado exitosamente', 'success');
      } else {
        // Create new order
        const orderData = {
          table: selectedTable.id,
          waiter: user?.username || user?.email || 'Sistema',
          items: cart.map(item => ({
            recipe: item.recipe.id,
            quantity: item.quantity,
            notes: item.notes || '',
            is_takeaway: item.is_takeaway || false
          })),
          container_sales: cart
            .filter(item => item.is_takeaway && item.recipe.container)
            .map(item => ({
              container: item.recipe.container,
              quantity: item.quantity
            }))
        };
        
        console.log('📋 Order data:', orderData);
        await api.post('/orders/', orderData);
        showToast('Pedido creado exitosamente', 'success');
      }

      // FIXED: Refresh both table orders and all orders to update table status
      await Promise.all([
        loadTableOrders(selectedTable.id),
        loadInitialData(true)
      ]);
      
      setCart([]);
      setCurrentOrder(null);
      setShowFloatingCart(false);
      setStep('orders');
      
    } catch (error) {
      console.error('❌ Error saving order:', error);
      const errorMessage = error.response?.data?.detail || 
                          error.response?.data?.message ||
                          'Error al guardar el pedido';
      showToast(errorMessage, 'error');
    } finally {
      setLoading(false);
    }
  };

  // Filtered and searched recipes
  const filteredRecipes = useMemo(() => {
    let filtered = recipes;
    
    if (selectedGroup) {
      filtered = filtered.filter(r => r.group?.id === selectedGroup);
    }
    
    if (searchTerm) {
      filtered = filtered.filter(r => 
        r.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        r.group?.name.toLowerCase().includes(searchTerm.toLowerCase())
      );
    }
    
    return filtered;
  }, [recipes, selectedGroup, searchTerm]);

  // Statistics calculations
  const stats = useMemo(() => {
    const availableTables = tables.filter(t => getTableStatus(t.id) === 'available').length;
    const occupiedTables = tables.filter(t => getTableStatus(t.id) === 'occupied').length;
    const totalActiveOrders = allOrders.length;
    const totalPendingSales = allOrders.reduce((sum, order) => 
      sum + parseFloat(order.grand_total || order.total_amount || 0), 0
    );

    return {
      availableTables,
      occupiedTables,
      totalActiveOrders,
      totalPendingSales
    };
  }, [tables, allOrders, getTableStatus]);

  // Main loading state
  if (loading && step === 'tables') {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center px-4">
        <div className="text-center">
          <div className="animate-spin rounded-full h-16 w-16 border-4 border-blue-500 border-t-transparent mx-auto mb-6"></div>
          <p className="text-gray-600 text-lg">Cargando restaurante...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 pb-20">
      {/* Mobile-Optimized Header */}
      <div className="bg-white shadow-sm border-b sticky top-0 z-40 safe-top">
        <div className="px-4 py-3">
          {/* Top row - Compact for mobile */}
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              {step !== 'tables' && (
                <button
                  onClick={() => {
                    if (step === 'orders') {
                      setStep('tables');
                      setSelectedTable(null);
                    } else if (step === 'menu' || step === 'cart') {
                      setStep('orders');
                      setCart([]);
                      setCurrentOrder(null);
                      setShowFloatingCart(false);
                    }
                  }}
                  className="p-2 text-gray-600 hover:text-gray-800 hover:bg-gray-100 rounded-lg transition-colors"
                >
                  <ChevronRight size={20} className="rotate-180" />
                </button>
              )}
              <div>
                <h1 className="text-lg font-bold text-gray-900 truncate">
                  {step === 'tables' && 'Mesas'}
                  {step === 'orders' && `Mesa ${selectedTable?.table_number}`}
                  {(step === 'menu' || step === 'cart') && (currentOrder ? 'Editar' : 'Nuevo')}
                </h1>
                {selectedTable && (
                  <p className="text-xs text-gray-500 truncate">{selectedTable.zone?.name}</p>
                )}
              </div>
            </div>
            
            {/* Action buttons - Compact */}
            <div className="flex items-center space-x-2">
              {step === 'tables' && (
                <button
                  onClick={() => loadInitialData(true)}
                  disabled={refreshing}
                  className="p-2 border border-gray-300 rounded-lg hover:bg-gray-50 disabled:opacity-50 transition-colors"
                >
                  <RefreshCw size={18} className={refreshing ? 'animate-spin' : ''} />
                </button>
              )}
              
              {step === 'menu' && (
                <button
                  onClick={() => setShowFilters(!showFilters)}
                  className="p-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  <Filter size={18} />
                </button>
              )}
            </div>
          </div>
          
          {/* Search bar for menu */}
          {step === 'menu' && (
            <div className="mt-3">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" size={18} />
                <input
                  type="text"
                  placeholder="Buscar platos..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>
            </div>
          )}

          {/* Category filters - Mobile horizontal scroll */}
          {step === 'menu' && showFilters && (
            <div className="mt-3 pb-2">
              <div className="flex space-x-2 overflow-x-auto scrollbar-hide">
                <button
                  onClick={() => setSelectedGroup(null)}
                  className={`flex-shrink-0 px-4 py-2 rounded-full text-sm font-medium transition-colors ${
                    !selectedGroup 
                      ? 'bg-blue-100 text-blue-700 border border-blue-200' 
                      : 'bg-white text-gray-700 border border-gray-300'
                  }`}
                >
                  Todos ({recipes.length})
                </button>
                {groups.map(group => (
                  <button
                    key={group.id}
                    onClick={() => setSelectedGroup(group.id)}
                    className={`flex-shrink-0 px-4 py-2 rounded-full text-sm font-medium transition-colors ${
                      selectedGroup === group.id 
                        ? 'bg-blue-100 text-blue-700 border border-blue-200' 
                        : 'bg-white text-gray-700 border border-gray-300'
                    }`}
                  >
                    {group.name}
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>

      <div className="px-4 py-4">
        {/* TABLES VIEW - Mobile Grid */}
        {step === 'tables' && (
          <div className="space-y-4">
            {/* Quick stats - Mobile 2x2 Grid */}
            <div className="grid grid-cols-2 gap-3">
              <div className="bg-green-50 p-4 rounded-lg border border-green-200">
                <div className="flex items-center space-x-2 mb-2">
                  <Check className="text-green-600" size={18} />
                  <span className="text-green-700 font-medium text-sm">Disponibles</span>
                </div>
                <div className="text-2xl font-bold text-green-700">
                  {stats.availableTables}
                </div>
              </div>
              
              <div className="bg-blue-50 p-4 rounded-lg border border-blue-200">
                <div className="flex items-center space-x-2 mb-2">
                  <Users className="text-blue-600" size={18} />
                  <span className="text-blue-700 font-medium text-sm">Ocupadas</span>
                </div>
                <div className="text-2xl font-bold text-blue-700">
                  {stats.occupiedTables}
                </div>
              </div>
              
              <div className="bg-purple-50 p-4 rounded-lg border border-purple-200">
                <div className="flex items-center space-x-2 mb-2">
                  <Coffee className="text-purple-600" size={18} />
                  <span className="text-purple-700 font-medium text-sm">Pedidos</span>
                </div>
                <div className="text-2xl font-bold text-purple-700">
                  {stats.totalActiveOrders}
                </div>
              </div>
              
              <div className="bg-orange-50 p-4 rounded-lg border border-orange-200">
                <div className="flex items-center space-x-2 mb-2">
                  <DollarSign className="text-orange-600" size={18} />
                  <span className="text-orange-700 font-medium text-sm">Ventas</span>
                </div>
                <div className="text-lg font-bold text-orange-700">
                  S/ {stats.totalPendingSales.toFixed(0)}
                </div>
              </div>
            </div>

            {/* Tables grid - Mobile optimized */}
            <div>
              <h2 className="text-lg font-semibold text-gray-900 mb-3">
                Seleccione una mesa
              </h2>
              
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                {tables.map(table => {
                  const status = getTableStatus(table.id);
                  const summary = getTableSummary(table.id);
                  const duration = summary?.duration || '';
                  
                  return (
                    <div
                      key={table.id}
                      className={`relative p-4 rounded-xl border-2 transition-all cursor-pointer haptic-light touch-target ${
                        status === 'available' 
                          ? 'status-available border-green-200' 
                          : duration.includes('h') && parseInt(duration.split('h')[0]) >= 2
                          ? 'status-danger border-red-200'
                          : duration.includes('h') && parseInt(duration.split('h')[0]) >= 1
                          ? 'status-warning border-yellow-200'
                          : 'status-occupied border-blue-200'
                      }`}
                      onClick={() => handleTableSelect(table)}
                    >
                      {/* Table header */}
                      <div className="text-center mb-3">
                        <div className="w-10 h-10 mx-auto mb-2 rounded-full bg-white flex items-center justify-center shadow-sm">
                          {status === 'available' ? (
                            <Check className="text-green-600" size={18} />
                          ) : duration.includes('h') && parseInt(duration.split('h')[0]) >= 2 ? (
                            <AlertCircle className="text-red-600" size={18} />
                          ) : duration.includes('h') && parseInt(duration.split('h')[0]) >= 1 ? (
                            <Clock className="text-yellow-600" size={18} />
                          ) : (
                            <Users className="text-blue-600" size={18} />
                          )}
                        </div>
                        <h3 className="font-bold text-gray-900">
                          Mesa {table.table_number}
                        </h3>
                        <p className="text-xs text-gray-600">{table.zone?.name}</p>
                      </div>

                      {/* Table status */}
                      {status === 'available' ? (
                        <div className="text-center">
                          <div className="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-green-100 text-green-700">
                            Disponible
                          </div>
                        </div>
                      ) : (
                        <div className="space-y-2">
                          <div className="text-center">
                            <div className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-white bg-opacity-80 mb-2">
                              {summary.orderCount} pedido{summary.orderCount > 1 ? 's' : ''}
                            </div>
                          </div>
                          
                          <div className="text-xs text-gray-700 space-y-1">
                            <div className="flex justify-between">
                              <span>Items:</span>
                              <span className="font-medium">{summary.totalItems}</span>
                            </div>
                            <div className="flex justify-between">
                              <span>Total:</span>
                              <span className="font-medium">S/ {summary.totalAmount.toFixed(2)}</span>
                            </div>
                            <div className="flex justify-between">
                              <span>Tiempo:</span>
                              <span className="font-medium">{duration}</span>
                            </div>
                          </div>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        )}

        {/* ORDERS VIEW - Mobile optimized */}
        {step === 'orders' && selectedTable && (
          <div className="space-y-4">
            {/* Header with add button */}
            <div className="flex justify-between items-center">
              <div>
                <h2 className="text-xl font-bold text-gray-900">
                  Mesa {selectedTable.table_number}
                </h2>
                <p className="text-gray-600 text-sm">{selectedTable.zone?.name}</p>
              </div>
              <button
                onClick={handleCreateNewOrder}
                className="flex items-center space-x-2 bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors font-medium text-sm"
              >
                <Plus size={18} />
                <span>Nuevo</span>
              </button>
            </div>

            {/* Orders list */}
            {orders.length === 0 ? (
              <div className="text-center py-12">
                <Coffee className="mx-auto h-16 w-16 text-gray-400 mb-4" />
                <h3 className="text-lg font-medium text-gray-900 mb-2">
                  Sin pedidos
                </h3>
                <p className="text-gray-600 mb-6 px-4">
                  Esta mesa no tiene pedidos pendientes
                </p>
                <button
                  onClick={handleCreateNewOrder}
                  className="inline-flex items-center space-x-2 text-green-600 hover:text-green-700 font-medium"
                >
                  <Plus size={20} />
                  <span>Crear pedido</span>
                </button>
              </div>
            ) : (
              <div className="space-y-4">
                {orders.map(order => (
                  <div key={order.id} className="bg-white rounded-xl border shadow-sm p-4">
                    {/* Order header */}
                    <div className="flex justify-between items-start mb-3">
                      <div>
                        <h3 className="text-lg font-bold text-gray-900">
                          Pedido #{order.id}
                        </h3>
                        <div className="flex items-center space-x-2 text-xs text-gray-600 mt-1">
                          <Clock size={14} />
                          <span>{new Date(order.created_at).toLocaleTimeString()}</span>
                          {order.waiter && (
                            <span>• {order.waiter}</span>
                          )}
                        </div>
                      </div>
                      <button
                        onClick={() => handleEditOrder(order)}
                        className="flex items-center space-x-1 text-blue-600 hover:text-blue-700 px-3 py-2 rounded-lg hover:bg-blue-50 transition-colors text-sm"
                      >
                        <Edit3 size={14} />
                        <span>Editar</span>
                      </button>
                    </div>

                    {/* Order items - Compact mobile view */}
                    <div className="space-y-2 mb-3">
                      {order.items?.slice(0, 3).map((item, idx) => (
                        <div key={idx} className="flex justify-between items-start py-2 border-b border-gray-100 last:border-b-0">
                          <div className="flex-1">
                            <h4 className="font-medium text-gray-900 text-sm">{item.recipe?.name}</h4>
                            {item.notes && (
                              <p className="text-xs text-gray-600 mt-1 italic truncate">
                                {item.notes}
                              </p>
                            )}
                            {item.is_takeaway && (
                              <span className="inline-flex items-center space-x-1 text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded-full mt-1">
                                <Package size={10} />
                                <span>Llevar</span>
                              </span>
                            )}
                          </div>
                          <div className="text-right ml-2">
                            <div className="font-bold">×{item.quantity}</div>
                            <div className="text-xs text-gray-600">S/ {item.total_price}</div>
                          </div>
                        </div>
                      ))}
                      {(order.items?.length || 0) > 3 && (
                        <div className="text-center text-xs text-gray-500 py-1">
                          +{(order.items?.length || 0) - 3} items más
                        </div>
                      )}
                    </div>

                    {/* Order total */}
                    <div className="flex justify-between items-center pt-3 border-t border-gray-200">
                      <div className="text-gray-600 text-sm">
                        {order.items?.length || 0} item{(order.items?.length || 0) !== 1 ? 's' : ''}
                      </div>
                      <div className="text-right">
                        <div className="text-xl font-bold text-gray-900">
                          S/ {order.grand_total || order.total_amount}
                        </div>
                        <div className="text-xs text-orange-600 font-medium">
                          Pendiente
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* MENU VIEW - Mobile optimized */}
        {step === 'menu' && (
          <div className="space-y-4">
            <div className="grid gap-3">
              {filteredRecipes.map(recipe => (
                <div key={recipe.id} className="bg-white rounded-lg border shadow-sm p-4">
                  <div className="flex justify-between items-start">
                    <div className="flex-1">
                      <h4 className="font-bold text-gray-900 text-lg mb-1">{recipe.name}</h4>
                      
                      {recipe.group && (
                        <span className="inline-block text-xs bg-gray-100 text-gray-600 px-2 py-1 rounded-full mb-2">
                          {recipe.group.name}
                        </span>
                      )}
                      
                      <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-4">
                          <span className="text-xl font-bold text-green-600">
                            S/ {recipe.base_price}
                          </span>
                          <span className="text-sm text-gray-600 flex items-center space-x-1">
                            <Clock size={14} />
                            <span>{recipe.preparation_time}min</span>
                          </span>
                        </div>
                        <button
                          onClick={() => addToCart(recipe)}
                          className="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors font-medium text-sm"
                        >
                          Agregar
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
            
            {filteredRecipes.length === 0 && (
              <div className="text-center py-12">
                <Coffee className="mx-auto h-16 w-16 text-gray-400 mb-4" />
                <h3 className="text-lg font-medium text-gray-900">
                  Sin resultados
                </h3>
                <p className="text-gray-600">
                  {searchTerm ? 'No se encontraron platos con ese nombre' : 
                   selectedGroup ? 'Esta categoría no tiene platos' : 'No hay platos disponibles'}
                </p>
              </div>
            )}
          </div>
        )}

        {/* CART VIEW - Mobile optimized */}
        {step === 'cart' && (
          <div className="space-y-4">
            <div className="bg-white rounded-xl shadow-sm border">
              {/* Cart header */}
              <div className="p-4 border-b border-gray-200">
                <h2 className="text-xl font-bold text-gray-900">
                  Carrito
                </h2>
                <p className="text-gray-600 text-sm">
                  Mesa {selectedTable?.table_number}
                </p>
              </div>

              <div className="p-4">
                {cart.length === 0 ? (
                  <div className="text-center py-8">
                    <ShoppingCart className="mx-auto h-16 w-16 text-gray-400 mb-4" />
                    <h3 className="text-lg font-medium text-gray-900 mb-2">
                      Carrito vacío
                    </h3>
                    <p className="text-gray-600 mb-6">
                      Agregue platos del menú
                    </p>
                    <button
                      onClick={() => setStep('menu')}
                      className="inline-flex items-center space-x-2 text-green-600 hover:text-green-700 font-medium"
                    >
                      <Plus size={20} />
                      <span>Agregar platos</span>
                    </button>
                  </div>
                ) : (
                  <div className="space-y-4">
                    {/* Cart items - Mobile optimized */}
                    <div className="space-y-3">
                      {cart.map((item, index) => (
                        <div key={index} className="border border-gray-200 rounded-lg p-3">
                          <div className="flex justify-between items-start mb-3">
                            <h4 className="font-bold text-gray-900 flex-1">{item.recipe.name}</h4>
                            <button
                              onClick={() => removeFromCart(index)}
                              className="ml-2 text-red-600 hover:text-red-700 p-1"
                            >
                              <X size={18} />
                            </button>
                          </div>
                          
                          {/* Quantity controls */}
                          <div className="flex items-center justify-between mb-3">
                            <span className="text-sm font-medium text-gray-700">Cantidad:</span>
                            <div className="flex items-center space-x-2">
                              <button
                                onClick={() => updateCartItem(index, { 
                                  quantity: Math.max(1, item.quantity - 1) 
                                })}
                                className="w-8 h-8 rounded-full border-2 border-gray-300 flex items-center justify-center"
                              >
                                <Minus size={14} />
                              </button>
                              <span className="w-8 text-center font-medium">{item.quantity}</span>
                              <button
                                onClick={() => updateCartItem(index, { 
                                  quantity: item.quantity + 1 
                                })}
                                className="w-8 h-8 rounded-full border-2 border-gray-300 flex items-center justify-center"
                              >
                                <Plus size={14} />
                              </button>
                            </div>
                          </div>

                          {/* Notes */}
                          <div className="mb-3">
                            <input
                              type="text"
                              value={item.notes}
                              onChange={(e) => updateCartItem(index, { notes: e.target.value })}
                              placeholder="Notas especiales..."
                              className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                            />
                          </div>

                          {/* Takeaway option */}
                          <div className="flex items-center justify-between">
                            <div className="flex items-center space-x-2">
                              <input
                                type="checkbox"
                                id={`takeaway-${index}`}
                                checked={item.is_takeaway}
                                onChange={(e) => updateCartItem(index, { is_takeaway: e.target.checked })}
                                className="rounded border-gray-300"
                              />
                              <label htmlFor={`takeaway-${index}`} className="text-sm font-medium text-gray-700">
                                Para llevar
                              </label>
                            </div>
                            <div className="text-right">
                              <div className="text-lg font-bold text-gray-900">
                                S/ {item.total_price.toFixed(2)}
                              </div>
                              <div className="text-xs text-gray-600">
                                S/ {item.unit_price.toFixed(2)} c/u
                              </div>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>

                    {/* Cart summary */}
                    <div className="bg-gray-50 rounded-lg p-4">
                      <div className="space-y-2 text-right">
                        <div className="flex justify-between">
                          <span className="font-medium">Comida:</span>
                          <span className="font-bold">S/ {getCartTotal().toFixed(2)}</span>
                        </div>
                        
                        {getContainerTotal() > 0 && (
                          <div className="flex justify-between">
                            <span className="font-medium">Envases:</span>
                            <span className="font-bold">S/ {getContainerTotal().toFixed(2)}</span>
                          </div>
                        )}
                        
                        <div className="flex justify-between text-xl font-bold border-t border-gray-300 pt-2">
                          <span>Total:</span>
                          <span className="text-green-600">S/ {getGrandTotal().toFixed(2)}</span>
                        </div>
                      </div>

                      {/* Action buttons */}
                      <div className="flex space-x-3 mt-4">
                        <button
                          onClick={() => setStep('menu')}
                          className="flex-1 px-4 py-3 border-2 border-gray-300 rounded-lg hover:bg-gray-50 transition-colors font-medium"
                        >
                          Continuar
                        </button>
                        <button
                          onClick={saveOrder}
                          disabled={loading}
                          className="flex-1 px-4 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 transition-colors font-medium"
                        >
                          {loading ? 'Guardando...' : (currentOrder ? 'Actualizar' : 'Crear')}
                        </button>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Floating Cart Button - Mobile */}
      {(step === 'menu') && cart.length > 0 && (
        <div className="fixed bottom-6 right-6 z-50">
          <button
            onClick={() => setStep('cart')}
            className="bg-blue-600 text-white p-4 rounded-full shadow-lg hover:bg-blue-700 transition-all haptic-medium flex items-center space-x-2 relative"
          >
            <ShoppingCart size={24} />
            <span className="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-6 h-6 flex items-center justify-center text-sm font-bold">
              {cart.length}
            </span>
          </button>
          {/* Total preview */}
          <div className="absolute bottom-full right-0 mb-2 bg-gray-900 text-white px-3 py-1 rounded-lg text-sm font-medium">
            S/ {getGrandTotal().toFixed(2)}
          </div>
        </div>
      )}

      {/* Order Details Modal - Mobile optimized */}
      {selectedOrderDetails && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-end justify-center z-50">
          <div className="bg-white rounded-t-lg w-full max-h-96 overflow-y-auto mobile-modal safe-bottom">
            <div className="p-4 border-b border-gray-200">
              <div className="flex justify-between items-center">
                <h3 className="text-lg font-bold text-gray-900">
                  Mesa {selectedOrderDetails[0]?.table?.table_number}
                </h3>
                <button
                  onClick={() => setSelectedOrderDetails(null)}
                  className="text-gray-400 hover:text-gray-600 p-1"
                >
                  <X size={24} />
                </button>
              </div>
            </div>
            
            <div className="p-4 space-y-3">
              {selectedOrderDetails.map(order => (
                <div key={order.id} className="border border-gray-200 rounded-lg p-3">
                  <div className="flex justify-between items-start mb-2">
                    <div>
                      <h4 className="font-bold text-gray-900">Pedido #{order.id}</h4>
                      <div className="text-sm text-gray-600 flex items-center space-x-2 mt-1">
                        <Clock size={12} />
                        <span>{new Date(order.created_at).toLocaleString()}</span>
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="font-bold">S/ {order.grand_total || order.total_amount}</div>
                      <div className="text-xs text-gray-600">{order.items?.length || 0} items</div>
                    </div>
                  </div>
                  
                  <div className="space-y-1">
                    {order.items?.map((item, idx) => (
                      <div key={idx} className="flex justify-between items-center text-sm py-1 border-b border-gray-100 last:border-b-0">
                        <span className="font-medium">{item.recipe?.name}</span>
                        <span>×{item.quantity}</span>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default RestaurantOperationsMobile;