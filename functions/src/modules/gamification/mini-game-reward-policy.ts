import {DomainError} from '../../platform/errors';
import type {DocumentData} from '../../platform/firestore/store';
import {InputValidationError} from '../../platform/validation';

/** Source gates only: no environment, policy or request field can open issuance. */
export const MINI_GAME_REWARD_RELEASE_APPROVED = false;
export const MINI_GAME_REWARD_ACCEPTED_VERIFICATION_VERSIONS: readonly string[] = Object.freeze([]);
export const MINI_GAME_REWARD_TIMEZONE = 'Asia/Kuala_Lumpur' as const;
export const MINI_GAME_REWARD_GAME_IDS = Object.freeze(['move-catch-v1']);
export interface MiniGameRewardGamePolicy {gameId: string; points: number; dailyClaimLimit: number}
export interface MiniGameRewardPolicy {
  schemaVersion: 1; revision: number; version: string; enabled: false;
  timezone: typeof MINI_GAME_REWARD_TIMEZONE; dailyPointsCap: number;
  games: MiniGameRewardGamePolicy[]; updatedAtMillis: number;
}
export const rewardInteger = (value: unknown, minimum = 0, maximum = Number.MAX_SAFE_INTEGER): value is number =>
  Number.isSafeInteger(value) && Number(value) >= minimum && Number(value) <= maximum;
export const rewardTime = (value: unknown): value is number => rewardInteger(value, 1, 8640000000000000);
export function defaultMiniGameRewardPolicy(): MiniGameRewardPolicy {
  return {schemaVersion: 1, revision: 0, version: 'mini-game-rewards-draft-v1', enabled: false,
    timezone: MINI_GAME_REWARD_TIMEZONE, dailyPointsCap: 60,
    games: [{gameId: 'move-catch-v1', points: 20, dailyClaimLimit: 1}], updatedAtMillis: 0};
}
export function validateMiniGameRewardFields(data: DocumentData): Pick<MiniGameRewardPolicy, 'dailyPointsCap' | 'games'> {
  if (!rewardInteger(data.dailyPointsCap, 0, 10000) || !Array.isArray(data.games)
      || data.games.length !== MINI_GAME_REWARD_GAME_IDS.length) throw new InputValidationError('Invalid mini-game reward policy.');
  const games: MiniGameRewardGamePolicy[] = [];
  for (const value of data.games) {
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new InputValidationError('Invalid game reward configuration.');
    const game = value as DocumentData;
    if (Object.keys(game).length !== 3 || Object.keys(game).some(key => !['gameId', 'points', 'dailyClaimLimit'].includes(key))
        || typeof game.gameId !== 'string' || !MINI_GAME_REWARD_GAME_IDS.includes(game.gameId)
        || games.some(row => row.gameId === game.gameId) || !rewardInteger(game.points, 0, 1000)
        || !rewardInteger(game.dailyClaimLimit, 0, 1)) throw new InputValidationError('Only supported games and at most one claim per game per day are allowed.');
    games.push({gameId: game.gameId, points: game.points, dailyClaimLimit: game.dailyClaimLimit});
  }
  return {dailyPointsCap: data.dailyPointsCap, games: games.sort((a, b) => a.gameId.localeCompare(b.gameId))};
}
export function parseMiniGameRewardPolicy(data: DocumentData | undefined, organizationId: string): MiniGameRewardPolicy {
  if (!data) return defaultMiniGameRewardPolicy();
  const fail = () => new DomainError('failed-precondition', 'Mini-game reward policy is unavailable.');
  if (data.schemaVersion !== 1 || data.organizationId !== organizationId || data.enabled !== false
      || data.timezone !== MINI_GAME_REWARD_TIMEZONE || !rewardInteger(data.revision, 1)
      || data.version !== `mini-game-rewards-v${data.revision}` || !rewardTime(data.updatedAtMillis)) throw fail();
  let fields: ReturnType<typeof validateMiniGameRewardFields>;
  try {fields = validateMiniGameRewardFields(data);} catch {throw fail();}
  return {schemaVersion: 1, revision: data.revision, version: data.version as string, enabled: false,
    timezone: MINI_GAME_REWARD_TIMEZONE, ...fields, updatedAtMillis: data.updatedAtMillis};
}
/** Malaysia has fixed UTC+08:00; the caller supplies only trusted server time. */
export function miniGameRewardDate(now: number): string {
  if (!rewardTime(now) || now > 8640000000000000 - 8 * 3600000) throw new DomainError('failed-precondition', 'Server reward time unavailable.');
  return new Date(now + 8 * 3600000).toISOString().slice(0, 10);
}
