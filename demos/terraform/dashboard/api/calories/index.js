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
        // Fetch intake and burn data in parallel, ordered oldest-first for charting
        const [intakeRes, burnRes] = await Promise.all([
            httpGet(`${DAB_BASE}/FuelGaugeCalories?$orderby=EntryDate%20asc&$first=14`),
            httpGet(`${DAB_BASE}/FuelGaugeCalorieBurn?$orderby=EntryDate%20asc&$first=14`),
        ]);

        const intake = JSON.parse(intakeRes.body).value ?? [];
        const burn   = JSON.parse(burnRes.body).value  ?? [];

        // Index burn data by date for O(1) lookup
        const burnByDate = {};
        for (const row of burn) {
            burnByDate[row.EntryDate] = row;
        }

        // Merge: every intake row gets the matching burn figures (or zeros)
        const merged = intake.map(row => ({
            EntryDate:        row.EntryDate,
            DailyTotal:       row.DailyTotal       ?? 0,
            BmrCalories:      burnByDate[row.EntryDate]?.BmrCalories      ?? 0,
            ActivityCalories: burnByDate[row.EntryDate]?.ActivityCalories  ?? 0,
        }));

        context.res = {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ value: merged }),
        };
    } catch (err) {
        context.res = {
            status: 502,
            body: JSON.stringify({ error: err.message }),
        };
    }
};
