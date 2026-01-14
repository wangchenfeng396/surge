package config

import (
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/fsnotify/fsnotify"
)

// ConfigWatcher monitors the configuration file for changes and triggers reload
type ConfigWatcher struct {
	configPath  string
	manager     *ConfigManager
	watcher     *fsnotify.Watcher
	debouncer   *time.Timer
	reloadFunc  func() error // Callback function to reload the engine
	mu          sync.Mutex
	running     bool
	stopCh      chan struct{}
	debounceDur time.Duration
}

// NewConfigWatcher creates a new configuration file watcher
func NewConfigWatcher(configPath string, manager *ConfigManager, reloadFunc func() error) (*ConfigWatcher, error) {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		return nil, fmt.Errorf("failed to create file watcher: %v", err)
	}

	return &ConfigWatcher{
		configPath:  configPath,
		manager:     manager,
		watcher:     watcher,
		reloadFunc:  reloadFunc,
		stopCh:      make(chan struct{}),
		debounceDur: 300 * time.Millisecond, // 300ms debounce
	}, nil
}

// Start begins monitoring the configuration file
func (w *ConfigWatcher) Start() error {
	w.mu.Lock()
	if w.running {
		w.mu.Unlock()
		return fmt.Errorf("config watcher already running")
	}
	w.running = true
	w.mu.Unlock()

	// Add the config file to the watcher
	if err := w.watcher.Add(w.configPath); err != nil {
		return fmt.Errorf("failed to watch config file: %v", err)
	}

	log.Printf("ConfigWatcher: Started monitoring %s", w.configPath)

	// Start the event loop
	go w.watchLoop()

	return nil
}

// Stop stops monitoring the configuration file
func (w *ConfigWatcher) Stop() error {
	w.mu.Lock()
	defer w.mu.Unlock()

	if !w.running {
		return nil
	}

	close(w.stopCh)
	w.running = false

	if w.debouncer != nil {
		w.debouncer.Stop()
	}

	if err := w.watcher.Close(); err != nil {
		return fmt.Errorf("failed to close watcher: %v", err)
	}

	log.Println("ConfigWatcher: Stopped")
	return nil
}

// watchLoop is the main event loop for file watching
func (w *ConfigWatcher) watchLoop() {
	for {
		select {
		case event, ok := <-w.watcher.Events:
			if !ok {
				return
			}

			// We're interested in Write and Create events
			if event.Has(fsnotify.Write) || event.Has(fsnotify.Create) {
				log.Printf("ConfigWatcher: Detected change in %s", event.Name)
				w.scheduleReload()
			}

		case err, ok := <-w.watcher.Errors:
			if !ok {
				return
			}
			log.Printf("ConfigWatcher: Error: %v", err)

		case <-w.stopCh:
			return
		}
	}
}

// scheduleReload schedules a config reload with debouncing
func (w *ConfigWatcher) scheduleReload() {
	w.mu.Lock()
	defer w.mu.Unlock()

	// Reset the debounce timer
	if w.debouncer != nil {
		w.debouncer.Stop()
	}

	w.debouncer = time.AfterFunc(w.debounceDur, func() {
		if err := w.triggerReload(); err != nil {
			log.Printf("ConfigWatcher: Reload failed: %v", err)
		}
	})
}

// triggerReload validates and triggers the configuration reload
func (w *ConfigWatcher) triggerReload() error {
	log.Println("ConfigWatcher: Triggering config reload...")

	// Create a backup before reload
	if err := w.manager.CreateBackup(); err != nil {
		log.Printf("ConfigWatcher: Warning - failed to create backup: %v", err)
	}

	// Load the new configuration
	if err := w.manager.Load(); err != nil {
		log.Printf("ConfigWatcher: Failed to load config: %v", err)
		// Try to restore from backup
		if restoreErr := w.manager.RestoreBackup(); restoreErr != nil {
			log.Printf("ConfigWatcher: Failed to restore backup: %v", restoreErr)
		}
		return fmt.Errorf("config load failed: %v", err)
	}

	// Validate the new configuration
	if err := w.manager.Validate(); err != nil {
		log.Printf("ConfigWatcher: Config validation failed: %v", err)
		// Restore from backup
		if restoreErr := w.manager.RestoreBackup(); restoreErr != nil {
			log.Printf("ConfigWatcher: Failed to restore backup: %v", restoreErr)
		}
		return fmt.Errorf("config validation failed: %v", err)
	}

	// Call the reload function to apply the new config
	if w.reloadFunc != nil {
		if err := w.reloadFunc(); err != nil {
			log.Printf("ConfigWatcher: Engine reload failed: %v", err)
			// Restore from backup
			if restoreErr := w.manager.RestoreBackup(); restoreErr != nil {
				log.Printf("ConfigWatcher: Failed to restore backup: %v", restoreErr)
			}
			return fmt.Errorf("engine reload failed: %v", err)
		}
	}

	log.Println("ConfigWatcher: Config reload successful")
	return nil
}

// IsRunning returns whether the watcher is currently running
func (w *ConfigWatcher) IsRunning() bool {
	w.mu.Lock()
	defer w.mu.Unlock()
	return w.running
}
