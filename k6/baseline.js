import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '30s', target: 500 },   // Ramp up to 500 RPS
    { duration: '1m', target: 1000 },   // Ramp up to 1000 RPS
    { duration: '2m', target: 1500 },   // Ramp up to 1500 RPS
    { duration: '2m', target: 1500 },   // Stay at 1500 RPS
    { duration: '30s', target: 0 },     // Ramp down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<200'],  // 95% of requests should be below 200ms
    'errors': ['rate<0.01'],              // Error rate should be below 1%
    'http_req_failed': ['rate<0.01'],     // Failed requests should be below 1%
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8081';
const API_KEY = __ENV.API_KEY || 'dev-secret-key';

const REGIONS = ['EU', 'NA', 'APAC'];
const MATCHES = ['match-1', 'match-2', 'match-3'];

function randomElement(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

export default function () {
  const userId = `user-${Math.floor(Math.random() * 10000)}`;
  const region = randomElement(REGIONS);
  const matchId = randomElement(MATCHES);

  const headers = {
    'Content-Type': 'application/json',
    'X-API-KEY': API_KEY,
  };

  // 70% heartbeats, 30% drink events
  if (Math.random() < 0.7) {
    const heartbeatPayload = JSON.stringify({
      userId: userId,
      region: region,
      matchId: matchId,
      amount: 0,
    });

    const heartbeatRes = http.post(
      `${BASE_URL}/api/events/heartbeat`,
      heartbeatPayload,
      { headers }
    );

    check(heartbeatRes, {
      'heartbeat status is 202': (r) => r.status === 202,
    }) || errorRate.add(1);

  } else {
    const drinkPayload = JSON.stringify({
      userId: userId,
      region: region,
      matchId: matchId,
      amount: Math.floor(Math.random() * 3) + 1,
    });

    const drinkRes = http.post(
      `${BASE_URL}/api/events/drink`,
      drinkPayload,
      { headers }
    );

    check(drinkRes, {
      'drink status is 202': (r) => r.status === 202,
    }) || errorRate.add(1);
  }

  sleep(0.1);
}
