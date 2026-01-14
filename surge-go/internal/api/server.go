package api

import (
	"encoding/json"
	"log"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"time"

	"github.com/gorilla/mux"
	"github.com/gorilla/websocket"
	"github.com/surge-proxy/surge-go/internal/config"
	"github.com/surge-proxy/surge-go/internal/engine"
	"github.com/surge-proxy/surge-go/internal/policy"
	"github.com/surge-proxy/surge-go/internal/system"
)

// Server represents the API server
type Server struct {
	router        *mux.Router
	engine        *engine.Engine
	upgrader      websocket.Upgrader
	configManager *config.ConfigManager
	sysProxyMgr   *system.ProxyManager
	testClient    *http.Client
}

// NewServer creates API server
func NewServer(eng *engine.Engine, configPath string) *Server {
	configMgr, err := config.NewConfigManager(configPath)
	if err != nil {
		log.Printf("Warning: failed to create config manager: %v", err)
	}

	// Initialize shared test client (proxy to local 8888)
	// This reduces overhead of creating new transport/client for every test
	proxyURL, _ := url.Parse("http://127.0.0.1:8888")
	testClient := &http.Client{
		Transport: &http.Transport{
			Proxy:               http.ProxyURL(proxyURL),
			MaxIdleConns:        100,
			MaxIdleConnsPerHost: 20,
		},
		Timeout: 5 * time.Second,
	}

	s := &Server{
		engine:        eng,
		configManager: configMgr,
		sysProxyMgr:   system.NewProxyManager(),
		testClient:    testClient,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true
			},
		},
	}

	s.setupRoutes()
	return s
}

// setupRoutes configures API routes
func (s *Server) setupRoutes() {
	s.router = mux.NewRouter()

	// Stats endpoints
	s.router.HandleFunc("/api/stats", s.handleStats).Methods("GET")
	s.router.HandleFunc("/api/proxies", s.handleProxies).Methods("GET")
	s.router.HandleFunc("/api/health", s.handleHealth).Methods("GET")

	// Control endpoints
	s.router.HandleFunc("/api/proxy/start", s.handleStart).Methods("POST")
	s.router.HandleFunc("/api/proxy/stop", s.handleStop).Methods("POST")
	s.router.HandleFunc("/api/proxy/switch", s.handleSwitchProxy).Methods("POST")
	s.router.HandleFunc("/api/proxy/toggle", s.handleToggleProxy).Methods("POST")
	s.router.HandleFunc("/api/proxy/mode", s.handleSetProxyMode).Methods("POST")
	s.router.HandleFunc("/api/proxy/test", s.handleTestProxy).Methods("POST")

	// Monitor endpoints
	s.router.HandleFunc("/api/connections", s.handleGetConnections).Methods("GET")
	s.router.HandleFunc("/api/capture", s.handleGetCapture).Methods("GET")
	s.router.HandleFunc("/api/processes", s.handleGetProcesses).Methods("GET")
	s.router.HandleFunc("/api/devices", s.handleGetDevices).Methods("GET")

	// Configuration endpoints
	s.router.HandleFunc("/api/config", s.handleGetConfig).Methods("GET")
	s.router.HandleFunc("/api/config", s.handleUpdateConfig).Methods("POST")
	s.router.HandleFunc("/api/config/general", s.handleGetGeneral).Methods("GET")
	s.router.HandleFunc("/api/config/general", s.handleUpdateGeneral).Methods("PUT")
	s.router.HandleFunc("/api/config/proxies", s.handleGetProxies).Methods("GET")
	s.router.HandleFunc("/api/config/proxies", s.handleAddProxy).Methods("POST")
	s.router.HandleFunc("/api/config/proxies/{name}", s.handleUpdateProxyByName).Methods("PUT")
	s.router.HandleFunc("/api/config/proxies/{name}", s.handleDeleteProxy).Methods("DELETE")
	s.router.HandleFunc("/api/config/proxy-groups", s.handleGetProxyGroups).Methods("GET")
	s.router.HandleFunc("/api/config/proxy-groups", s.handleAddProxyGroup).Methods("POST")
	s.router.HandleFunc("/api/config/proxy-groups/{name}", s.handleUpdateProxyGroup).Methods("PUT")
	s.router.HandleFunc("/api/config/proxy-groups/{name}", s.handleDeleteProxyGroup).Methods("DELETE")
	s.router.HandleFunc("/api/config/proxy-groups/{name}/select", s.handleSelectProxy).Methods("POST")
	s.router.HandleFunc("/api/config/rules", s.handleGetRulesConfig).Methods("GET")
	s.router.HandleFunc("/api/config/rules", s.handleAddRule).Methods("POST")
	s.router.HandleFunc("/api/config/rules/{index}", s.handleUpdateRule).Methods("PUT")
	s.router.HandleFunc("/api/config/rules/{index}", s.handleDeleteRule).Methods("DELETE")
	s.router.HandleFunc("/api/config/rules/move", s.handleMoveRule).Methods("POST")

	// System integration endpoints
	s.router.HandleFunc("/api/system-proxy/enable", s.handleEnableSystemProxy).Methods("POST")
	s.router.HandleFunc("/api/system-proxy/disable", s.handleDisableSystemProxy).Methods("POST")
	s.router.HandleFunc("/api/system-proxy/status", s.handleSystemProxyStatus).Methods("GET")
	s.router.HandleFunc("/api/tun/enable", s.handleEnableTUN).Methods("POST")
	s.router.HandleFunc("/api/tun/disable", s.handleDisableTUN).Methods("POST")
	s.router.HandleFunc("/api/tun/status", s.handleTUNStatus).Methods("GET")

	// Legacy rules endpoints
	s.router.HandleFunc("/api/rules", s.handleGetRules).Methods("GET")
	s.router.HandleFunc("/api/rules", s.handleUpdateRules).Methods("POST")
	s.router.HandleFunc("/api/rules/detail", s.handleGetRulesDetail).Methods("GET")
	s.router.HandleFunc("/api/rules/reset-counters", s.handleResetRuleCounters).Methods("POST")
	s.router.HandleFunc("/api/rules/{id}/toggle", s.handleToggleRule).Methods("POST")
	s.router.HandleFunc("/api/proxies/global", s.handleSetGlobalProxy).Methods("POST")

	// WebSocket
	s.router.HandleFunc("/ws", s.handleWebSocket)

	// Backend Specific API
	s.router.HandleFunc("/api/rules/match", s.handleRuleMatch).Methods("POST")
	s.router.HandleFunc("/api/dns/query", s.handleDNSQuery).Methods("GET")
	s.router.HandleFunc("/api/dns/diagnose", s.handleDNSDiagnose).Methods("GET")
	s.router.HandleFunc("/api/proxy/test", s.handleTestProxy).Methods("POST")
	s.router.HandleFunc("/api/proxy/test-live", s.handleTestProxyLive).Methods("POST")
	s.router.HandleFunc("/api/system/gateway", s.handleSystemGateway).Methods("GET")

	// Host management endpoints
	s.router.HandleFunc("/api/config/hosts", s.handleGetHosts).Methods("GET")
	s.router.HandleFunc("/api/config/hosts", s.handleAddHost).Methods("POST")
	s.router.HandleFunc("/api/config/hosts/{domain}", s.handleUpdateHost).Methods("PUT")
	s.router.HandleFunc("/api/config/hosts/{domain}", s.handleDeleteHost).Methods("DELETE")

	// URL Rewrite endpoints
	s.router.HandleFunc("/api/config/url-rewrites", s.handleGetURLRewrites).Methods("GET")
	s.router.HandleFunc("/api/config/url-rewrites", s.handleAddURLRewrite).Methods("POST")
	s.router.HandleFunc("/api/config/url-rewrites/{index}", s.handleUpdateURLRewrite).Methods("PUT")
	s.router.HandleFunc("/api/config/url-rewrites/{index}", s.handleDeleteURLRewrite).Methods("DELETE")

	// Header Rewrite endpoints
	s.router.HandleFunc("/api/config/header-rewrites", s.handleGetHeaderRewrites).Methods("GET")
	s.router.HandleFunc("/api/config/header-rewrites", s.handleAddHeaderRewrite).Methods("POST")
	s.router.HandleFunc("/api/config/header-rewrites/{index}", s.handleUpdateHeaderRewrite).Methods("PUT")
	s.router.HandleFunc("/api/config/header-rewrites/{index}", s.handleDeleteHeaderRewrite).Methods("DELETE")

	// MITM configuration endpoints
	s.router.HandleFunc("/api/config/mitm", s.handleGetMITM).Methods("GET")
	s.router.HandleFunc("/api/config/mitm", s.handleUpdateMITM).Methods("PUT")

	// Config validation and reload endpoints
	s.router.HandleFunc("/api/config/validate", s.handleValidateConfig).Methods("POST")
	s.router.HandleFunc("/api/config/reload", s.handleReloadConfig).Methods("POST")
	s.router.HandleFunc("/api/config/reload-status", s.handleReloadStatus).Methods("GET")

	// CORS done via wrapper in Start()
}

// Start starts the API server
func (s *Server) Start() error {
	addr := ":9090"
	if s.engine.Config != nil && s.engine.Config.General.HTTPAPI != "" {
		addr = s.engine.Config.General.HTTPAPI
	}
	log.Printf("Starting API server on %s", addr)
	handler := CORSMiddleware(s.router)
	return http.ListenAndServe(addr, handler)
}

// Handlers

func (s *Server) handleStats(w http.ResponseWriter, r *http.Request) {
	stats := s.engine.GetStats()
	respondJSON(w, stats)
}

func (s *Server) handleGetConnections(w http.ResponseWriter, r *http.Request) {
	if s.engine.Tracker != nil {
		respondJSON(w, s.engine.Tracker.GetConnections())
	} else {
		respondJSON(w, []interface{}{})
	}
}

func (s *Server) handleGetCapture(w http.ResponseWriter, r *http.Request) {
	if s.engine.CaptureStore != nil {
		respondJSON(w, s.engine.CaptureStore.GetAll())
	} else {
		respondJSON(w, []interface{}{})
	}
}

func (s *Server) handleGetProcesses(w http.ResponseWriter, r *http.Request) {
	if s.engine.Stats != nil {
		respondJSON(w, s.engine.Stats.GetProcesses())
	} else {
		respondJSON(w, []interface{}{})
	}
}

func (s *Server) handleGetDevices(w http.ResponseWriter, r *http.Request) {
	if s.engine.Stats != nil {
		respondJSON(w, s.engine.Stats.GetDevices())
	} else {
		respondJSON(w, []interface{}{})
	}
}

func (s *Server) handleProxies(w http.ResponseWriter, r *http.Request) {
	proxies := s.engine.GetProxyList()
	respondJSON(w, map[string]interface{}{
		"proxies": proxies,
	})
}

func (s *Server) handleStart(w http.ResponseWriter, r *http.Request) {
	if err := s.engine.Start(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	respondJSON(w, map[string]string{"status": "started"})
}

func (s *Server) handleStop(w http.ResponseWriter, r *http.Request) {
	if err := s.engine.Stop(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	respondJSON(w, map[string]string{"status": "stopped"})
}

func (s *Server) handleUpdateConfig(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Config string `json:"config"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// TODO: Parse config string to struct
	// For now logging
	log.Printf("Config update requested (reloading engine not fully impl)")

	// if err := s.engine.Reload(...); err != nil { ... }

	respondJSON(w, map[string]string{"status": "updated"})
}

func (s *Server) handleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WebSocket upgrade failed: %v", err)
		return
	}
	defer conn.Close()

	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		stats := s.engine.GetStats()
		if err := conn.WriteJSON(stats); err != nil {
			break
		}
	}
}

func (s *Server) handleGetRules(w http.ResponseWriter, r *http.Request) {
	// Return current rules from config
	// For now, return empty array - will be populated from actual config
	var rules []string
	if s.configManager != nil {
		cfg := s.configManager.GetConfig()
		for _, r := range cfg.Rules {
			line := r.Type
			if r.Value != "" {
				line += "," + r.Value
			}
			if r.Policy != "" {
				line += "," + r.Policy
			}
			if r.NoResolve {
				line += ",no-resolve"
			}
			for _, p := range r.Params {
				line += "," + p
			}
			rules = append(rules, line)
		}
	}
	respondJSON(w, map[string]interface{}{
		"rules": rules,
	})
}

func (s *Server) handleUpdateRules(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Rules []string `json:"rules"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// TODO: Update sing-box config with new rules
	// For now, just acknowledge receipt
	log.Printf("Received %d rules for update", len(req.Rules))

	respondJSON(w, map[string]string{"status": "updated"})
}

type RuleDTO struct {
	ID       int    `json:"id"`
	Type     string `json:"type"`
	Payload  string `json:"payload"`
	Adapter  string `json:"policy"`
	HitCount int64  `json:"hit_count"`
	Enabled  bool   `json:"enabled"`
	Comment  string `json:"comment"`
}

func (s *Server) handleGetRulesDetail(w http.ResponseWriter, r *http.Request) {
	rules := s.engine.RuleEngine.GetRules()
	var dtos []RuleDTO
	for i, rule := range rules {
		dtos = append(dtos, RuleDTO{
			ID:       i,
			Type:     rule.Type(),
			Payload:  rule.Payload(),
			Adapter:  rule.Adapter(),
			HitCount: rule.HitCount(),
			Enabled:  rule.IsEnabled(),
			Comment:  rule.Comment(),
		})
	}
	respondJSON(w, map[string]interface{}{
		"rules": dtos,
	})
}

func (s *Server) handleResetRuleCounters(w http.ResponseWriter, r *http.Request) {
	s.engine.RuleEngine.ResetCounters()
	respondJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleToggleRule(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	indexStr := vars["id"]
	index, err := strconv.Atoi(indexStr)
	if err != nil {
		http.Error(w, "Invalid rule ID", http.StatusBadRequest)
		return
	}

	var req struct {
		Enabled bool `json:"enabled"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.engine.RuleEngine.ToggleRule(index, req.Enabled); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	respondJSON(w, map[string]string{"status": "ok"})
}

func (s *Server) handleSetGlobalProxy(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Proxy string `json:"proxy"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Ideally we should have a SetGlobalProxy method on Engine
	// But Global Mode relies on getAdapter logic.
	// We can add a "Global" select group?
	// Or a special state in engine.

	// For now, let's create a "Global" Select Group if it doesn't exist, or update it.
	// OR, update the "Global" group we saw in engine code?
	// engine.go: } else if p := e.getAdapter("Global"); p != nil {

	// It seems "Global" is expected to be a group/proxy name.
	// But usually Global Mode means "All traffic goes to ONE proxy".
	// We can implement this by having a special SelectGroup named "Global" that contains all proxies?

	// Let's check how engine handles global mode.
	// case "global":
	// 	if p := e.getAdapter("Proxy"); p != nil { ... }
	// 	else if p := e.getAdapter("Global"); p != nil { ... }

	// So if we have a group named "Global", it uses it.
	// If we want to change the proxy used in Global Mode, we should change the selection of "Global" (or "Proxy") group.

	// If the user wants to select a SPECIFIC proxy for Global Mode among ALL proxies (without a group),
	// we might need to dynamically update the "Global" group.

	// Let's assume there is a group named "Global" or "Proxy".
	// The frontend shows "Global Proxy" card.

	// If we want persistent selection:
	// We call handleSelectProxy on "Global" or "Proxy" group.

	// But the user request implies we want to select "which proxy used in global mode".
	// If "Global Mode" just routes to a group, then we just select on that group.
	// If "Global Mode" implies "Use any proxy as global", we need to create a group containing all proxies?

	// Let's reuse handleSelectProxy if possible, but expose a wrapper.
	// For now, let's look for "Global" or "Proxy" group and select on it.

	targetGroup := "Proxy"
	if s.engine.Groups["Global"] != nil {
		targetGroup = "Global"
	}

	// Check if group exists
	if s.engine.Groups[targetGroup] == nil {
		http.Error(w, "No global proxy group found", http.StatusInternalServerError)
		return
	}

	// Call select
	if sg, ok := s.engine.Groups[targetGroup].(*policy.SelectGroup); ok {
		sg.SetCurrent(req.Proxy)
		// Persist?
		// We need config manager to persist.
		// Reusing s.handleSelectProxy logic might be better.
	}

	// Trigger config update/save
	// ... logic similar to handleSelectProxy ...
	// For MVP, just update memory.

	respondJSON(w, map[string]string{"status": "ok", "group": targetGroup, "selected": req.Proxy})
}

// Helper functions

func respondJSON(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}

func CORSMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func (s *Server) handleGetConfig(w http.ResponseWriter, r *http.Request) {
	data, err := os.ReadFile("surge.conf")
	if err != nil {
		http.Error(w, "Config not found", 404)
		return
	}
	respondJSON(w, map[string]string{"config": string(data)})
}

func (s *Server) handleSwitchProxy(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Group string `json:"group"`
		Proxy string `json:"proxy"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	log.Printf("Switching proxy in group %s to %s", req.Group, req.Proxy)
	respondJSON(w, map[string]string{"status": "switched", "group": req.Group, "proxy": req.Proxy})
}

func (s *Server) handleToggleProxy(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name    string `json:"name"`
		Enabled bool   `json:"enabled"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	log.Printf("Toggling proxy %s to %v", req.Name, req.Enabled)
	respondJSON(w, map[string]string{"status": "updated", "name": req.Name})
}

func (s *Server) handleSetProxyMode(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Mode string `json:"mode"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	log.Printf("Setting proxy mode to: %s", req.Mode)

	if s.engine != nil {
		s.engine.SetMode(req.Mode)
	}

	respondJSON(w, map[string]string{"status": "success", "mode": req.Mode})
}
