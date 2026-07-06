import { put as presignedPut, get as presignedGet } from './presigned';
import {
    isConfigured as artifactsIsConfigured,
    get as artifactsGet,
} from './artifacts';
import {
    isConfigured as derivedIsConfigured,
    get as derivedGet,
} from './derived';
import { getObjectState as glacierGetObjectState } from './glacier';
import { remove as objectsRemove, listAll as objectsListAll } from './objects';
import {
    create as multipartCreate,
    signParts as multipartSignParts,
    signPartsByNumber as multipartSignPartsByNumber,
    listParts as multipartListParts,
    complete as multipartComplete,
    abort as multipartAbort,
} from './multipart';

const presigned = {
    put: presignedPut,
    get: presignedGet,
} as const;

const artifacts = {
    isConfigured: artifactsIsConfigured,
    get: artifactsGet,
} as const;

const derived = {
    isConfigured: derivedIsConfigured,
    get: derivedGet,
} as const;

const glacier = {
    getObjectState: glacierGetObjectState,
} as const;

const objects = {
    remove: objectsRemove,
    listAll: objectsListAll,
} as const;

const multipart = {
    create: multipartCreate,
    signParts: multipartSignParts,
    signPartsByNumber: multipartSignPartsByNumber,
    listParts: multipartListParts,
    complete: multipartComplete,
    abort: multipartAbort,
} as const;

/**
 * S3 storage operations for file archival
 *
 * @example
 * ```typescript
 * import { s3 } from '@/lib/storage';
 *
 * // Generate presigned URLs
 * const uploadUrl = await s3.presigned.put(key, { contentType: 'image/png' });
 * const downloadUrl = await s3.presigned.get(key, { filename: 'download.png' });
 *
 * // Glacier operations
 * const state = await s3.glacier.getObjectState(key);
 *
 * // Object operations
 * await s3.objects.remove(key);
 * ```
 */
export const s3 = {
    presigned,
    artifacts,
    derived,
    glacier,
    objects,
    multipart,
} as const;

// Re-export types for convenience
export type {
    RestoreTier,
    ObjectState,
    ObjectAvailability,
    PutPresignOptions,
    GetPresignOptions,
} from './types';
