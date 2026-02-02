#include <iostream>
#include <thread>
#include <chrono>
#include <iomanip>
#include "kvstore.h"

void printTimestamp(const std::chrono::system_clock::time_point& tp) {
    auto time_t = std::chrono::system_clock::to_time_t(tp);
    std::cout << std::put_time(std::localtime(&time_t), "%Y-%m-%d %H:%M:%S");
}

int main() {
    std::cout << "=== Temporal Key-Value Store Test ===\n\n";
    
    auto kvstore = std::make_shared<KVStore>(nullptr);
    
    // Set initial value
    std::cout << "1. Setting user=alice\n";
    kvstore->set("user", "alice");
    auto time1 = std::chrono::system_clock::now();
    
    // Wait a bit
    std::this_thread::sleep_for(std::chrono::milliseconds(100));
    
    // Update value
    std::cout << "2. Setting user=bob\n";
    kvstore->set("user", "bob");
    auto time2 = std::chrono::system_clock::now();
    
    // Wait a bit more
    std::this_thread::sleep_for(std::chrono::milliseconds(100));
    
    // Update again
    std::cout << "3. Setting user=charlie\n";
    kvstore->set("user", "charlie");
    auto time3 = std::chrono::system_clock::now();
    
    std::cout << "\n=== Current Value ===\n";
    auto current = kvstore->get("user");
    if (current) {
        std::cout << "GET user: " << *current << "\n";
    }
    
    std::cout << "\n=== Historical Values ===\n";
    auto history = kvstore->getHistory("user");
    std::cout << "Total versions: " << history.size() << "\n";
    for (size_t i = 0; i < history.size(); ++i) {
        std::cout << "Version " << (i+1) << ": ";
        printTimestamp(history[i].timestamp);
        std::cout << " -> \"" << history[i].value << "\"\n";
    }
    
    std::cout << "\n=== Time-Travel Queries ===\n";
    
    // Query at time1 (should be alice)
    auto valueAtTime1 = kvstore->getAtTime("user", time1);
    std::cout << "Value at time1: " << (valueAtTime1 ? *valueAtTime1 : "(nil)") << "\n";
    
    // Query at time2 (should be bob)
    auto valueAtTime2 = kvstore->getAtTime("user", time2);
    std::cout << "Value at time2: " << (valueAtTime2 ? *valueAtTime2 : "(nil)") << "\n";
    
    // Query at time3 (should be charlie)
    auto valueAtTime3 = kvstore->getAtTime("user", time3);
    std::cout << "Value at time3: " << (valueAtTime3 ? *valueAtTime3 : "(nil)") << "\n";
    
    // Query before any version
    auto timeBefore = time1 - std::chrono::seconds(1);
    auto valueBeforeAll = kvstore->getAtTime("user", timeBefore);
    std::cout << "Value before all versions: " << (valueBeforeAll ? *valueBeforeAll : "(nil)") << "\n";
    
    std::cout << "\n=== Multiple Keys ===\n";
    kvstore->set("email", "alice@example.com");
    std::this_thread::sleep_for(std::chrono::milliseconds(50));
    kvstore->set("email", "bob@example.com");
    
    auto emailHistory = kvstore->getHistory("email");
    std::cout << "Email versions: " << emailHistory.size() << "\n";
    for (const auto& v : emailHistory) {
        std::cout << "  - \"" << v.value << "\"\n";
    }
    
    std::cout << "\n=== Test Complete ===\n";
    return 0;
}
