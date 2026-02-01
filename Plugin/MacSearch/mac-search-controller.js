const { exec } = require('child_process');
const path = require('path');

/**
 * Execute search using macOS mdfind (Spotlight)
 */
function searchWithMdfind(query, maxResults = 50) {
    return new Promise((resolve, reject) => {
        // mdfind -name "query" or just mdfind "query"
        // We limit results using head
        const command = `mdfind "${query.replace(/"/g, '\\"')}" | head -n ${maxResults}`;
        
        exec(command, (error, stdout, stderr) => {
            if (error && error.code !== 0) {
                return reject(new Error(`mdfind failed: ${stderr || error.message}`));
            }
            
            const results = stdout.split('\n').filter(line => line.trim() !== '');
            resolve(results);
        });
    });
}

async function processRequest(request) {
    const { query, maxResults = 50 } = request;

    if (!query) {
        return {
            status: 'error',
            error: 'Missing required parameter: query',
        };
    }

    try {
        const results = await searchWithMdfind(query, maxResults);
        return {
            status: 'success',
            result: {
                searchQuery: query,
                resultCount: results.length,
                results: results,
            },
        };
    } catch (error) {
        return {
            status: 'error',
            error: error.message,
        };
    }
}

// stdio communication
let inputBuffer = '';
process.stdin.setEncoding('utf8');

process.stdin.on('data', (chunk) => {
    inputBuffer += chunk;
});

process.stdin.on('end', async () => {
    if (!inputBuffer.trim()) return;
    try {
        const request = JSON.parse(inputBuffer);
        const response = await processRequest(request);
        console.log(JSON.stringify(response));
    } catch (error) {
        console.log(JSON.stringify({ status: 'error', error: `Invalid JSON input: ${error.message}` }));
    }
});
