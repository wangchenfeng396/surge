package api

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptrace"
	"strconv"
	"time"

	"github.com/gorilla/mux"
	"github.com/surge-proxy/surge-go/internal/config"
	"github.com/surge-proxy/surge-go/internal/system"
)

// Health check handler
func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	respondJSON(w, map[string]string{"status": "ok"})
}

// Configuration management handlers

func (s *Server) handleGetGeneral(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}
	respondJSON(w, s.configManager.GetGeneral())
}

func (s *Server) handleUpdateGeneral(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	var cfg config.GeneralConfig
	if err := json.NewDecoder(r.Body).Decode(&cfg); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.UpdateGeneral(&cfg); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "updated"})
}

func (s *Server) handleGetProxies(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}
	respondJSON(w, s.configManager.GetProxies())
}

func (s *Server) handleAddProxy(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	var proxy config.ProxyConfig
	if err := json.NewDecoder(r.Body).Decode(&proxy); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.AddProxy(&proxy); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "added", "name": proxy.Name})
}

func (s *Server) handleUpdateProxyByName(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	vars := mux.Vars(r)
	name := vars["name"]

	var proxy config.ProxyConfig
	if err := json.NewDecoder(r.Body).Decode(&proxy); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.UpdateProxy(name, &proxy); err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "updated", "name": name})
}

func (s *Server) handleDeleteProxy(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	vars := mux.Vars(r)
	name := vars["name"]

	if err := s.configManager.DeleteProxy(name); err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "deleted", "name": name})
}

func (s *Server) handleGetProxyGroups(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}
	respondJSON(w, s.configManager.GetProxyGroups())
}

func (s *Server) handleAddProxyGroup(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	var group config.ProxyGroupConfig
	if err := json.NewDecoder(r.Body).Decode(&group); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.AddProxyGroup(&group); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "added", "name": group.Name})
}

func (s *Server) handleUpdateProxyGroup(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	vars := mux.Vars(r)
	name := vars["name"]

	var group config.ProxyGroupConfig
	if err := json.NewDecoder(r.Body).Decode(&group); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.UpdateProxyGroup(name, &group); err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "updated", "name": name})
}

func (s *Server) handleDeleteProxyGroup(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	vars := mux.Vars(r)
	name := vars["name"]

	if err := s.configManager.DeleteProxyGroup(name); err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "deleted", "name": name})
}

func (s *Server) handleSelectProxy(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil || s.engine == nil {
		http.Error(w, "System not initialized", http.StatusInternalServerError)
		return
	}

	vars := mux.Vars(r)
	groupName := vars["name"]

	var req struct {
		Proxy string `json:"proxy"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// 1. Update Runtime State
	if g, ok := s.engine.Groups[groupName]; ok {
		// Use interface check for broader compatibility (SelectGroup, etc.)
		// But only SelectGroup supports SetCurrent usually.
		// Let's rely on type assertion to SelectGroup for now as per plan.
		// Wait, package policy is imported? No, handlers.go doesn't seem to import "policy" directly?
		// Let me check imports. It imports "github.com/surge-proxy/surge-go/internal/config" and "github.com/surge-proxy/surge-go/internal/system".
		// It might need "github.com/surge-proxy/surge-go/internal/policy".
		// But accessing s.engine.Groups returns policy.Group interface.
		// I need to import "github.com/surge-proxy/surge-go/internal/policy".

		// For now, let's use a type assertion to an interface with SetCurrent.
		if sg, ok := g.(interface{ SetCurrent(string) error }); ok {
			if err := sg.SetCurrent(req.Proxy); err != nil {
				http.Error(w, err.Error(), http.StatusBadRequest)
				return
			}
		} else {
			http.Error(w, "Group does not support manual selection", http.StatusBadRequest)
			return
		}
	} else {
		http.Error(w, "Group not found", http.StatusNotFound)
		return
	}

	// 2. Persist to Config
	groupCfg, err := s.configManager.GetProxyGroup(groupName)
	if err == nil {
		groupCfg.Selected = req.Proxy
		// No need to call UpdateProxyGroup explicitly if we modified the pointer returned by GetProxyGroup?
		// GetProxyGroup returns *ProxyGroupConfig. configManager stores pointers?
		// Let's check manager.go. GetProxyGroup returns *ProxyGroupConfig using loop.
		// m.config.ProxyGroups is []*ProxyGroupConfig.
		// So modifying it modifies the in-memory config directly.
		s.configManager.Save()
	}

	respondJSON(w, map[string]string{"status": "ok", "selected": req.Proxy})
}

func (s *Server) handleGetRulesConfig(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}
	respondJSON(w, s.configManager.GetRules())
}

func (s *Server) handleAddRule(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	var rule config.RuleConfig
	if err := json.NewDecoder(r.Body).Decode(&rule); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.AddRule(&rule); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "added"})
}

func (s *Server) handleUpdateRule(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	vars := mux.Vars(r)
	indexStr := vars["index"]
	index, err := strconv.Atoi(indexStr)
	if err != nil {
		http.Error(w, "Invalid index", http.StatusBadRequest)
		return
	}

	var rule config.RuleConfig
	if err := json.NewDecoder(r.Body).Decode(&rule); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.UpdateRule(index, &rule); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "updated"})
}

func (s *Server) handleDeleteRule(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	vars := mux.Vars(r)
	indexStr := vars["index"]
	index, err := strconv.Atoi(indexStr)
	if err != nil {
		http.Error(w, "Invalid index", http.StatusBadRequest)
		return
	}

	if err := s.configManager.DeleteRule(index); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "deleted"})
}

func (s *Server) handleMoveRule(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	var req struct {
		FromIndex int `json:"from_index"`
		ToIndex   int `json:"to_index"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.MoveRule(req.FromIndex, req.ToIndex); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "moved"})
}

// System integration handlers

func (s *Server) handleEnableSystemProxy(w http.ResponseWriter, r *http.Request) {
	if s.sysProxyMgr == nil {
		http.Error(w, "System proxy manager not initialized", http.StatusInternalServerError)
		return
	}

	var req struct {
		Port int `json:"port"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Default port if not specified
	if req.Port == 0 {
		req.Port = 8888
	}

	if err := s.sysProxyMgr.Enable(req.Port); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]interface{}{
		"status": "enabled",
		"port":   req.Port,
	})
}

func (s *Server) handleDisableSystemProxy(w http.ResponseWriter, r *http.Request) {
	if s.sysProxyMgr == nil {
		http.Error(w, "System proxy manager not initialized", http.StatusInternalServerError)
		return
	}

	if err := s.sysProxyMgr.Disable(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "disabled"})
}

func (s *Server) handleSystemProxyStatus(w http.ResponseWriter, r *http.Request) {
	if s.sysProxyMgr == nil {
		http.Error(w, "System proxy manager not initialized", http.StatusInternalServerError)
		return
	}

	enabled, port := s.sysProxyMgr.GetStatus()

	var selectedProxy string
	if s.engine != nil {
		if g, ok := s.engine.Groups["Proxy"]; ok {
			// Check if it's a SelectGroup
			if sg, ok := g.(interface{ Now() string }); ok {
				selectedProxy = sg.Now()
			}
		}
	}

	respondJSON(w, map[string]interface{}{
		"enabled":        enabled,
		"port":           port,
		"selected_proxy": selectedProxy,
	})
}

func (s *Server) handleEnableTUN(w http.ResponseWriter, r *http.Request) {
	if s.engine == nil {
		http.Error(w, "Engine not initialized", http.StatusInternalServerError)
		return
	}

	if err := s.engine.EnableTUN(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "enabled"})
}

func (s *Server) handleDisableTUN(w http.ResponseWriter, r *http.Request) {
	if s.engine == nil {
		http.Error(w, "Engine not initialized", http.StatusInternalServerError)
		return
	}

	if err := s.engine.DisableTUN(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "disabled"})
}

func (s *Server) handleTUNStatus(w http.ResponseWriter, r *http.Request) {
	if s.engine == nil {
		http.Error(w, "Engine not initialized", http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]interface{}{
		"enabled": s.engine.IsTUNEnabled(),
	})
}

// New Backend Specific Endpoints

func (s *Server) handleRuleMatch(w http.ResponseWriter, r *http.Request) {
	var req struct {
		URL      string `json:"url"`
		SourceIP string `json:"source_ip"`
		Process  string `json:"process"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	adapter, rule, err := s.engine.MatchRule(req.URL, req.SourceIP, req.Process)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{
		"adapter": adapter,
		"rule":    rule,
	})
}

func (s *Server) handleDNSQuery(w http.ResponseWriter, r *http.Request) {
	host := r.URL.Query().Get("host")
	if host == "" {
		http.Error(w, "host parameter required", http.StatusBadRequest)
		return
	}

	ips, err := s.engine.ResolveDNS(host)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]interface{}{
		"host": host,
		"ips":  ips,
	})
}

func (s *Server) handleDNSDiagnose(w http.ResponseWriter, r *http.Request) {
	if s.engine == nil || s.engine.DNSManager == nil {
		respondJSON(w, map[string]int{})
		return
	}
	respondJSON(w, s.engine.DNSManager.TestUpstreams(r.Context()))
}

func (s *Server) handleSystemGateway(w http.ResponseWriter, r *http.Request) {
	gateway, iface, err := system.GetDefaultGateway()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	respondJSON(w, map[string]string{
		"gateway":   gateway,
		"interface": iface,
	})
}

func (s *Server) handleTestProxy(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name string `json:"name"`
		URL  string `json:"url"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if req.Name == "" {
		http.Error(w, "name parameter required", http.StatusBadRequest)
		return
	}

	metrics, err := s.engine.TestProxyDetailed(req.Name, req.URL)
	if err != nil {
		respondJSON(w, map[string]interface{}{
			"success": false,
			"name":    req.Name,
			"error":   err.Error(),
		})
		return
	}

	resp := map[string]interface{}{
		"success": true,
		"name":    req.Name,
		"latency": metrics["total"],
		"timing":  metrics,
	}
	// Add legacy key if present (for backward compatibility if anyone relies on it being just a number? No, respondJSON handles it)
	// But detailed keys are in 'timing'.
	// metrics map contains "tcp", "handshake", "total".
	// We put "latency" as total for compatibility.

	respondJSON(w, resp)
}

// handleTestProxyLive 通过代理服务器端口测试代理（方案B）
func (s *Server) handleTestProxyLive(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name string `json:"name"`
		URL  string `json:"url"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	testURL := req.URL
	if testURL == "" {
		testURL = "http://connect.rom.miui.com/generate_204"
	}

	// Use shared client to avoid local TCP handshake overhead
	client := s.testClient
	if client == nil {
		client = http.DefaultClient
	}

	// Trace timing
	var (
		start        = time.Now()
		connectStart time.Time
		connectDone  time.Time
		gotFirstByte time.Time
	)

	trace := &httptrace.ClientTrace{
		GetConn: func(hostPort string) {
			connectStart = time.Now()
		},
		GotConn: func(info httptrace.GotConnInfo) {
			connectDone = time.Now()
		},
		GotFirstResponseByte: func() {
			gotFirstByte = time.Now()
		},
	}

	ctx := httptrace.WithClientTrace(r.Context(), trace)
	outReq, err := http.NewRequestWithContext(ctx, "GET", testURL, nil)
	if err != nil {
		respondJSON(w, map[string]interface{}{
			"success": false,
			"error":   err.Error(),
		})
		return
	}

	if req.Name != "" {
		outReq.Header.Set("X-Surge-Test-Proxy", req.Name)
	}

	// Force disable compression to see raw transfer correctness if needed,
	// but for speed test usually we just want latency.
	// outReq.Header.Set("Accept-Encoding", "identity")

	resp, err := client.Do(outReq)

	totalLatency := time.Since(start).Milliseconds()

	if err != nil {
		respondJSON(w, map[string]interface{}{
			"success": false,
			"name":    req.Name,
			"error":   err.Error(),
		})
		return
	}
	defer resp.Body.Close()
	io.Copy(io.Discard, resp.Body)

	// Calculate timings
	// If reused connection, connectStart/Done might be zero or very close?
	// httptrace behaviour:
	// If connection is reused, GetConn is called, then GotConn with Reused=true.

	timing := map[string]interface{}{}

	if !connectStart.IsZero() && !connectDone.IsZero() {
		timing["connect"] = connectDone.Sub(connectStart).Milliseconds()
	}
	if !connectDone.IsZero() && !gotFirstByte.IsZero() {
		timing["ttfb"] = gotFirstByte.Sub(connectDone).Milliseconds()
	}
	timing["total"] = totalLatency

	respondJSON(w, map[string]interface{}{
		"success": true,
		"name":    req.Name,
		"latency": int(totalLatency),
		"timing":  timing,
	})
}

// ========== Host Management Handlers ==========

func (s *Server) handleGetHosts(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}
	respondJSON(w, s.configManager.GetHosts())
}

func (s *Server) handleAddHost(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	var host config.HostConfig
	if err := json.NewDecoder(r.Body).Decode(&host); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.AddHost(&host); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "added", "domain": host.Domain})
}

func (s *Server) handleUpdateHost(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	vars := mux.Vars(r)
	domain := vars["domain"]

	var host config.HostConfig
	if err := json.NewDecoder(r.Body).Decode(&host); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.UpdateHost(domain, &host); err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "updated", "domain": domain})
}

func (s *Server) handleDeleteHost(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	vars := mux.Vars(r)
	domain := vars["domain"]

	if err := s.configManager.DeleteHost(domain); err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "deleted", "domain": domain})
}

// ========== URL Rewrite Handlers ==========

func (s *Server) handleGetURLRewrites(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}
	respondJSON(w, s.configManager.GetURLRewrites())
}

func (s *Server) handleAddURLRewrite(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	var rewrite config.URLRewriteConfig
	if err := json.NewDecoder(r.Body).Decode(&rewrite); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.AddURLRewrite(&rewrite); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "added"})
}

func (s *Server) handleUpdateURLRewrite(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	vars := mux.Vars(r)
	indexStr := vars["index"]
	index, err := strconv.Atoi(indexStr)
	if err != nil {
		http.Error(w, "Invalid index", http.StatusBadRequest)
		return
	}

	var rewrite config.URLRewriteConfig
	if err := json.NewDecoder(r.Body).Decode(&rewrite); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.UpdateURLRewrite(index, &rewrite); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "updated"})
}

func (s *Server) handleDeleteURLRewrite(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	vars := mux.Vars(r)
	indexStr := vars["index"]
	index, err := strconv.Atoi(indexStr)
	if err != nil {
		http.Error(w, "Invalid index", http.StatusBadRequest)
		return
	}

	if err := s.configManager.DeleteURLRewrite(index); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "deleted"})
}

// ========== Header Rewrite Handlers ==========

func (s *Server) handleGetHeaderRewrites(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}
	respondJSON(w, s.configManager.GetHeaderRewrites())
}

func (s *Server) handleAddHeaderRewrite(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	var rewrite config.BodyRewriteConfig
	if err := json.NewDecoder(r.Body).Decode(&rewrite); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.AddHeaderRewrite(&rewrite); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "added"})
}

func (s *Server) handleUpdateHeaderRewrite(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	vars := mux.Vars(r)
	indexStr := vars["index"]
	index, err := strconv.Atoi(indexStr)
	if err != nil {
		http.Error(w, "Invalid index", http.StatusBadRequest)
		return
	}

	var rewrite config.BodyRewriteConfig
	if err := json.NewDecoder(r.Body).Decode(&rewrite); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.UpdateHeaderRewrite(index, &rewrite); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "updated"})
}

func (s *Server) handleDeleteHeaderRewrite(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	vars := mux.Vars(r)
	indexStr := vars["index"]
	index, err := strconv.Atoi(indexStr)
	if err != nil {
		http.Error(w, "Invalid index", http.StatusBadRequest)
		return
	}

	if err := s.configManager.DeleteHeaderRewrite(index); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "deleted"})
}

// ========== MITM Handlers ==========

func (s *Server) handleGetMITM(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}
	respondJSON(w, s.configManager.GetMITM())
}

func (s *Server) handleUpdateMITM(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	var mitm config.MITMConfig
	if err := json.NewDecoder(r.Body).Decode(&mitm); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.configManager.UpdateMITM(&mitm); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if err := s.configManager.Save(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to save config: %v", err), http.StatusInternalServerError)
		return
	}

	respondJSON(w, map[string]string{"status": "updated"})
}

// ========== Configuration Management Handlers ==========

func (s *Server) handleValidateConfig(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	if err := s.configManager.Validate(); err != nil {
		respondJSON(w, map[string]interface{}{
			"valid": false,
			"error": err.Error(),
		})
		return
	}

	respondJSON(w, map[string]interface{}{
		"valid": true,
	})
}

func (s *Server) handleReloadConfig(w http.ResponseWriter, r *http.Request) {
	if s.configManager == nil {
		http.Error(w, "Config manager not initialized", http.StatusInternalServerError)
		return
	}

	// Create backup
	if err := s.configManager.CreateBackup(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to create backup: %v", err), http.StatusInternalServerError)
		return
	}

	// Load configuration
	if err := s.configManager.Load(); err != nil {
		http.Error(w, fmt.Sprintf("Failed to load config: %v", err), http.StatusInternalServerError)
		return
	}

	// Validate
	if err := s.configManager.Validate(); err != nil {
		// Restore backup on validation failure
		s.configManager.RestoreBackup()
		http.Error(w, fmt.Sprintf("Config validation failed: %v", err), http.StatusBadRequest)
		return
	}

	// Reload engine
	if s.engine != nil {
		if err := s.engine.Reload(s.configManager.GetConfig()); err != nil {
			// Restore backup on reload failure
			s.configManager.RestoreBackup()
			http.Error(w, fmt.Sprintf("Engine reload failed: %v", err), http.StatusInternalServerError)
			return
		}
	}

	respondJSON(w, map[string]string{"status": "reloaded"})
}

func (s *Server) handleReloadStatus(w http.ResponseWriter, r *http.Request) {
	// For now, just return a simple status
	// In the future, we can track reload progress
	respondJSON(w, map[string]interface{}{
		"status":      "idle",
		"last_reload": nil,
	})
}
