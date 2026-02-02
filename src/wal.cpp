#include "wal.h"
#include <iostream>
#include <sstream>
#include <sys/stat.h>
#include <sys/types.h>
#include <cerrno>
#include <cstring>

WAL::WAL(const std::string& path) : walPath(path), enabled(false) {
    // Derive snapshot path from WAL path
    size_t lastSlash = path.find_last_of("/\\");
    if (lastSlash != std::string::npos) {
        snapshotPath = path.substr(0, lastSlash) + "/snapshot.db";
    } else {
        snapshotPath = "snapshot.db";
    }
}

WAL::~WAL() {
    if (logFile.is_open()) {
        try {
            logFile.flush();
            logFile.close();
        } catch (...) {
            // Silently handle errors during destruction
        }
    }
}

Status WAL::initialize() {
    try {
        // Extract directory path from file path
        size_t lastSlash = walPath.find_last_of("/\\");
        if (lastSlash != std::string::npos) {
            std::string dirPath = walPath.substr(0, lastSlash);
            if (!createDirectory(dirPath)) {
                std::cerr << "Warning: Failed to create WAL directory: " << dirPath << "\n";
                enabled = false;
                return Status::ERROR;
            }
        }
        
        // Open file in append mode
        logFile.open(walPath, std::ios::app);
        if (!logFile.is_open()) {
            std::cerr << "Warning: Failed to open WAL file: " << walPath << "\n";
            std::cerr << "Continuing without WAL (data will not persist)\n";
            enabled = false;
            return Status::ERROR;
        }
        
        enabled = true;
        std::cout << "WAL initialized: " << walPath << "\n";
        return Status::OK;
        
    } catch (const std::exception& e) {
        std::cerr << "Warning: WAL initialization error: " << e.what() << "\n";
        std::cerr << "Continuing without WAL (data will not persist)\n";
        enabled = false;
        return Status::ERROR;
    }
}

Status WAL::logSet(const std::string& key, const std::string& value,
                   std::chrono::system_clock::time_point timestamp) {
    if (!enabled || !logFile.is_open()) {
        return Status::ERROR;
    }
    
    try {
        // Convert timestamp to epoch milliseconds
        auto epochMs = std::chrono::duration_cast<std::chrono::milliseconds>(
            timestamp.time_since_epoch()).count();
        
        // Format: SET key value timestamp_ms
        logFile << "SET " << key << " " << value << " " << epochMs << "\n";
        logFile.flush(); // Ensure it's written to disk
        return Status::OK;
    } catch (const std::exception& e) {
        std::cerr << "Warning: Failed to write to WAL: " << e.what() << "\n";
        return Status::ERROR;
    }
}

Status WAL::logDel(const std::string& key) {
    if (!enabled || !logFile.is_open()) {
        return Status::ERROR;
    }
    
    try {
        logFile << "DEL " << key << "\n";
        logFile.flush(); // Ensure it's written to disk
        return Status::OK;
    } catch (const std::exception& e) {
        std::cerr << "Warning: Failed to write to WAL: " << e.what() << "\n";
        return Status::ERROR;
    }
}

Status WAL::logPolicy(const std::string& policyName) {
    if (!enabled || !logFile.is_open()) {
        return Status::ERROR;
    }
    
    try {
        logFile << "POLICY SET " << policyName << "\n";
        logFile.flush(); // Ensure it's written to disk
        return Status::OK;
    } catch (const std::exception& e) {
        std::cerr << "Warning: Failed to write to WAL: " << e.what() << "\n";
        return Status::ERROR;
    }
}

std::vector<std::string> WAL::readLog() {
    std::vector<std::string> commands;
    
    try {
        if (!fileExists(walPath)) {
            std::cout << "No existing WAL file found (starting fresh)\n";
            return commands;
        }
        
        std::ifstream inFile(walPath);
        if (!inFile.is_open()) {
            std::cerr << "Warning: Failed to open WAL for reading: " << walPath << "\n";
            return commands;
        }
        
        std::string line;
        while (std::getline(inFile, line)) {
            if (!line.empty()) {
                commands.push_back(line);
            }
        }
        
        inFile.close();
        
        if (!commands.empty()) {
            std::cout << "Loaded " << commands.size() << " commands from WAL\n";
        }
        
    } catch (const std::exception& e) {
        std::cerr << "Warning: Error reading WAL: " << e.what() << "\n";
    }
    
    return commands;
}

std::vector<std::string> WAL::readSnapshot() {
    std::vector<std::string> commands;
    
    try {
        if (!fileExists(snapshotPath)) {
            // No snapshot exists, which is fine
            return commands;
        }
        
        std::ifstream inFile(snapshotPath);
        if (!inFile.is_open()) {
            std::cerr << "Warning: Failed to open snapshot for reading: " << snapshotPath << "\n";
            return commands;
        }
        
        std::string line;
        while (std::getline(inFile, line)) {
            if (!line.empty()) {
                commands.push_back(line);
            }
        }
        
        inFile.close();
        
        if (!commands.empty()) {
            std::cout << "Loaded snapshot with " << commands.size() << " keys\n";
        }
        
    } catch (const std::exception& e) {
        std::cerr << "Warning: Error reading snapshot: " << e.what() << "\n";
    }
    
    return commands;
}

Status WAL::createSnapshot(const std::unordered_map<std::string, std::string>& data,
                          const std::string& currentPolicy) {
    try {
        // Open snapshot file for writing (truncate mode)
        std::ofstream snapFile(snapshotPath, std::ios::trunc);
        if (!snapFile.is_open()) {
            std::cerr << "Error: Failed to create snapshot file: " << snapshotPath << "\n";
            return Status::ERROR;
        }
        
        // Write policy first (if provided)
        if (!currentPolicy.empty()) {
            snapFile << "POLICY SET " << currentPolicy << "\n";
        }
        
        // Write all key-value pairs as SET commands
        for (const auto& [key, value] : data) {
            snapFile << "SET " << key << " " << value << "\n";
        }
        
        snapFile.flush();
        snapFile.close();
        
        // Clear the WAL after successful snapshot
        Status clearStatus = clearLog();
        if (clearStatus != Status::OK) {
            std::cerr << "Warning: Snapshot created but failed to clear WAL\n";
            return Status::ERROR;
        }
        
        std::cout << "Snapshot created with " << data.size() << " keys\n";
        return Status::OK;
        
    } catch (const std::exception& e) {
        std::cerr << "Error: Failed to create snapshot: " << e.what() << "\n";
        return Status::ERROR;
    }
}

bool WAL::isEnabled() const {
    return enabled;
}

void WAL::flush() {
    if (logFile.is_open()) {
        try {
            logFile.flush();
        } catch (...) {
            // Silently handle flush errors
        }
    }
}

bool WAL::createDirectory(const std::string& path) {
    try {
        struct stat st;
        
        // Check if directory already exists
        if (stat(path.c_str(), &st) == 0) {
            if (S_ISDIR(st.st_mode)) {
                return true; // Directory exists
            }
            return false; // Path exists but is not a directory
        }
        
        // Create directory with permissions 0755
        if (mkdir(path.c_str(), 0755) == 0) {
            return true;
        }
        
        // Check if it failed because directory now exists (race condition)
        if (errno == EEXIST) {
            return true;
        }
        
        std::cerr << "Failed to create directory: " << strerror(errno) << "\n";
        return false;
        
    } catch (...) {
        return false;
    }
}

bool WAL::fileExists(const std::string& path) {
    struct stat st;
    return (stat(path.c_str(), &st) == 0);
}

Status WAL::clearLog() {
    try {
        // Close current log file
        if (logFile.is_open()) {
            logFile.close();
        }
        
        // Open in truncate mode to clear contents
        std::ofstream clearFile(walPath, std::ios::trunc);
        if (!clearFile.is_open()) {
            std::cerr << "Error: Failed to clear WAL log\n";
            enabled = false;
            return Status::ERROR;
        }
        clearFile.close();
        
        // Reopen in append mode
        logFile.open(walPath, std::ios::app);
        if (!logFile.is_open()) {
            std::cerr << "Error: Failed to reopen WAL after clearing\n";
            enabled = false;
            return Status::ERROR;
        }
        
        std::cout << "WAL log cleared\n";
        return Status::OK;
        
    } catch (const std::exception& e) {
        std::cerr << "Error: Failed to clear WAL: " << e.what() << "\n";
        enabled = false;
        return Status::ERROR;
    }
}
