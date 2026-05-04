const http = require('http');

const DAB_BASE = process.env.DAB_ENDPOINT || '';

function httpGet(url) {
    return new Promise((resolve, reject) => {
        http.get(url, res => {
            let body = '';
            res.on('data', chunk => body += chunk);
            res.on('end', () => resolve({ status: res.statusCode, body }));
        }).on('error', reject);
    });
}

module.exports = async function (context, req) {
    try {
        const { status, body } = await httpGet(
            `${DAB_BASE}/IntervalsWellness?$orderby=RecordDate%20desc&$first=1`
        );
        context.res = {
            status,
            headers: { 'Content-Type': 'application/json' },
            body,
        };
    } catch (err) {
        context.res = {
            status: 502,
            body: JSON.stringify({ error: err.message }),
        };
    }
};
