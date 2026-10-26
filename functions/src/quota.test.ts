import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  adGrantsPerMonth,
  anonymousLifetimeCalls,
  cooldownMs,
  includedNamesPerMonth,
  meterCounts,
  adGrantGapMs,
  releaseAnonymousFree,
  releaseName,
  releaseReservedCall,
  reserveCall,
  reserveIdentify,
  takeAdGrant,
  takeAnonymousFree,
  takeFreeNotMushroom,
  takeName,
} from './quota';

const march = Date.parse('2026-03-02T12:00:00Z');
const april = Date.parse('2026-04-01T00:00:00Z');

test('a guest has one free name and gets it back when the photo is not a mushroom', () => {
  const first = takeAnonymousFree(null);
  assert.equal(first.free, true);
  assert.equal(first.state.anonymousFreeUsed, true);
  const again = takeAnonymousFree(first.state);
  assert.equal(again.free, false);
  const released = releaseAnonymousFree(first.state);
  assert.equal(takeAnonymousFree(released).free, true);
});

test('a signed-in month is five names, plus five from ads, and rolls over', () => {
  let state = takeName(null, march).state;
  for (let i = 1; i < includedNamesPerMonth; i++) state = takeName(state, march).state;
  assert.equal(takeName(state, march).taken, false);
  const granted = takeAdGrant(state, march, adGrantsPerMonth);
  assert.equal(granted.granted, true);
  assert.equal(takeName(granted.state, march).taken, true);
  const full = { ...granted.state, namesUsed: 10, adGrants: 5 };
  assert.equal(takeAdGrant(full, march, adGrantsPerMonth).granted, false);
  assert.deepEqual(meterCounts(full, april), { namesUsed: 0, adGrants: 0 });
});

test('a guest call waits, and three attempts ask for an account', () => {
  const limits = {
    dailyCeiling: 15,
    cooldownMs,
    repeatWindowMs: 24 * 60 * 60 * 1000,
    lifetimeCeiling: anonymousLifetimeCalls,
  };
  const first = reserveCall(null, march, 'a', limits);
  if (!('state' in first)) assert.fail('expected a reserved call');
  const soon = reserveCall(first.state, march + 1000, 'b', limits);
  assert.deepEqual(soon, { refusal: 'cooldown' });
  const second = reserveCall(first.state, march + cooldownMs, 'b', limits);
  if (!('state' in second)) assert.fail('expected a reserved call');
  const third = reserveCall(second.state, march + cooldownMs * 2, 'c', limits);
  if (!('state' in third)) assert.fail('expected a reserved call');
  assert.deepEqual(reserveCall(third.state, march + cooldownMs * 3, 'd', limits), {
    refusal: 'sign-in',
  });
});

test('a no-names refusal does not spend a daily call', () => {
  const limits = {
    dailyCeiling: 15,
    cooldownMs,
    repeatWindowMs: 24 * 60 * 60 * 1000,
  };
  const full = {
    namesUsed: includedNamesPerMonth,
    dayCalls: 2,
    totalCalls: 2,
    month: '2026-03',
    day: '2026-03-02',
  };
  assert.deepEqual(reserveIdentify(full, march, 'photo', limits, true), { refusal: 'no-names' });
  const open = reserveIdentify(
    { namesUsed: 1, dayCalls: 2, totalCalls: 2, month: '2026-03', day: '2026-03-02' },
    march,
    'photo',
    limits,
    true,
  );
  if (!('state' in open)) assert.fail('expected a reserved call');
  assert.equal(open.state.dayCalls, 3);
  assert.equal(open.state.totalCalls, 3);
  const released = releaseReservedCall(open.state);
  assert.equal(released.dayCalls, 2);
  assert.equal(released.totalCalls, 2);
  assert.equal(released.lastCallAt, undefined);
});

test('an ad grant waits out the gap and then counts', () => {
  const first = takeAdGrant(null, march, adGrantsPerMonth);
  assert.equal(first.granted, true);
  const burst = takeAdGrant(first.state, march + 1000, adGrantsPerMonth);
  assert.equal(burst.granted, false);
  assert.equal(burst.state.adGrants, 1);
  const later = takeAdGrant(first.state, march + adGrantGapMs, adGrantsPerMonth);
  assert.equal(later.granted, true);
  assert.equal(later.state.adGrants, 2);
});

test('a failed call and a free not-a-mushroom answer give the name back', () => {
  const held = takeName(null, march);
  assert.equal(releaseName(held.state).namesUsed, 0);
  const free = takeFreeNotMushroom(held.state, march, 3);
  assert.equal(free.free, true);
  let spent = free.state;
  spent = takeFreeNotMushroom(spent, march, 3).state;
  spent = takeFreeNotMushroom(spent, march, 3).state;
  assert.equal(takeFreeNotMushroom(spent, march, 3).free, false);
});
