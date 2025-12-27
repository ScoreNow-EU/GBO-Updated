// Console filter to remove unwanted debug messages
(function() {
    'use strict';
    
    // Store the original console methods
    const originalLog = console.log;
    const originalError = console.error;
    const originalWarn = console.warn;
    
    // Filtered messages we want to hide
    const filteredMessages = [
        'Cannot send Null',
        'DebugService: Error serving requests',
        'Unsupported operation: Cannot send Null'
    ];
    
    // Function to check if a message should be filtered
    function shouldFilter(message) {
        if (typeof message === 'string') {
            return filteredMessages.some(filter => message.includes(filter));
        }
        return false;
    }
    
    // Override console.log
    console.log = function(...args) {
        const firstArg = args[0];
        if (!shouldFilter(firstArg)) {
            originalLog.apply(console, args);
        }
    };
    
    // Override console.error
    console.error = function(...args) {
        const firstArg = args[0];
        if (!shouldFilter(firstArg)) {
            originalError.apply(console, args);
        }
    };
    
    // Override console.warn
    console.warn = function(...args) {
        const firstArg = args[0];
        if (!shouldFilter(firstArg)) {
            originalWarn.apply(console, args);
        }
    };
    
    console.log('🔇 Console filter initialized - "Cannot send Null" errors will be silenced');
})();
