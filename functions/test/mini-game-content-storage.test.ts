import {beforeEach, expect, it, vi} from 'vitest';
const mocks = vi.hoisted(() => ({getMetadata: vi.fn(), save: vi.fn(), file: vi.fn(), bucket: vi.fn()}));
vi.mock('firebase-admin/storage', () => ({getStorage: () => ({bucket: mocks.bucket})}));
import {FirebaseMiniGameMediaStore} from '../src/modules/content/mini-game-content-storage';

const objectPath = 'orgs/gainpath/miniGameMedia/move-catch-v1/cover/admin/' + 'a'.repeat(32);
const bytes = Buffer.from('synthetic bytes'), sha256 = 'd'.repeat(64), token = '12345678-1234-1234-1234-123456789abc';
const metadata = () => ({contentType: 'image/png', size: bytes.length, metadata: {gainpathSha256: sha256, firebaseStorageDownloadTokens: token}});
beforeEach(() => {
  vi.resetAllMocks();
  mocks.bucket.mockReturnValue({name: 'synthetic-bucket', file: mocks.file});
  mocks.file.mockReturnValue({getMetadata: mocks.getMetadata, save: mocks.save});
});
it('creates immutable objects with a generation-zero precondition and validates readback', async () => {
  mocks.getMetadata.mockRejectedValueOnce({code: 404}).mockResolvedValueOnce([metadata()]);
  const url = await new FirebaseMiniGameMediaStore().upload(objectPath, bytes, 'image/png', sha256);
  expect(mocks.file).toHaveBeenCalledWith(objectPath);
  expect(mocks.save).toHaveBeenCalledWith(bytes, expect.objectContaining({resumable: false, preconditionOpts: {ifGenerationMatch: 0},
    metadata: expect.objectContaining({contentType: 'image/png', metadata: {gainpathSha256: sha256, firebaseStorageDownloadTokens: expect.stringMatching(/^[a-f0-9-]{36}$/)}})}));
  expect(url).toBe(`https://firebasestorage.googleapis.com/v0/b/synthetic-bucket/o/${encodeURIComponent(objectPath)}?alt=media&token=${token}`);
});
it('recovers same-content retries without overwriting an existing object', async () => {
  mocks.getMetadata.mockResolvedValue([metadata()]);
  await new FirebaseMiniGameMediaStore().upload(objectPath, bytes, 'image/png', sha256);
  expect(mocks.save).not.toHaveBeenCalled();
});
it('recovers a generation-precondition race by validating the winning object', async () => {
  mocks.getMetadata.mockRejectedValueOnce({code: 404}).mockResolvedValueOnce([metadata()]); mocks.save.mockRejectedValue({code: 412});
  await expect(new FirebaseMiniGameMediaStore().upload(objectPath, bytes, 'image/png', sha256)).resolves.toContain(`token=${token}`);
});
it.each(['digest', 'size', 'type', 'token'])('rejects existing mismatched %s metadata', async mode => {
  const meta = metadata();
  if (mode === 'digest') meta.metadata.gainpathSha256 = 'other';
  if (mode === 'size') meta.size++;
  if (mode === 'type') meta.contentType = 'image/jpeg';
  if (mode === 'token') meta.metadata.firebaseStorageDownloadTokens = '';
  mocks.getMetadata.mockResolvedValue([meta]);
  await expect(new FirebaseMiniGameMediaStore().upload(objectPath, bytes, 'image/png', sha256)).rejects.toMatchObject({code: 'already-exists'});
  expect(mocks.save).not.toHaveBeenCalled();
});
it('preserves infrastructure failures without attempting an overwrite', async () => {
  mocks.getMetadata.mockRejectedValue({code: 403});
  await expect(new FirebaseMiniGameMediaStore().upload(objectPath, bytes, 'image/png', sha256)).rejects.toMatchObject({code: 403});
  expect(mocks.save).not.toHaveBeenCalled();
});
