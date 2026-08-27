/**
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
import { SupersetClient } from '@superset-ui/core';
import {
  DatasetOption,
  PreviewResult,
  Report,
  ReportDefinition,
} from './types';

const BASE = '/reportdesigner/api';

export async function fetchDatasets(): Promise<DatasetOption[]> {
  const { json } = await SupersetClient.get({ endpoint: `${BASE}/datasets/` });
  return json.result ?? [];
}

export async function fetchReports(): Promise<Report[]> {
  const { json } = await SupersetClient.get({ endpoint: `${BASE}/` });
  return json.result ?? [];
}

export async function fetchReport(id: number): Promise<Report> {
  const { json } = await SupersetClient.get({ endpoint: `${BASE}/${id}/` });
  return json;
}

export async function createReport(
  name: string,
  description: string,
  definition: ReportDefinition,
): Promise<Report> {
  const { json } = await SupersetClient.post({
    endpoint: `${BASE}/`,
    jsonPayload: { name, description, definition },
  });
  return json;
}

export async function updateReport(
  id: number,
  name: string,
  description: string,
  definition: ReportDefinition,
): Promise<Report> {
  const { json } = await SupersetClient.put({
    endpoint: `${BASE}/${id}/`,
    jsonPayload: { name, description, definition },
  });
  return json;
}

export async function deleteReport(id: number): Promise<void> {
  await SupersetClient.delete({ endpoint: `${BASE}/${id}/` });
}

export async function previewReport(
  definition: ReportDefinition,
): Promise<PreviewResult> {
  const { json } = await SupersetClient.post({
    endpoint: `${BASE}/preview/`,
    jsonPayload: { definition },
  });
  return json;
}

export function exportReportUrl(id: number): string {
  return `${BASE}/${id}/export.csv/`;
}

export function exportXlsxUrl(id: number): string {
  return `${BASE}/${id}/export.xlsx/`;
}

export function exportPdfUrl(id: number): string {
  return `${BASE}/${id}/export.pdf/`;
}

export type UploadResult = {
  dataset_id: number;
  table_name: string;
  rows: number;
  columns: string[];
};

export type DatabaseOption = {
  id: number;
  database_name: string;
};

export async function fetchDatabases(): Promise<DatabaseOption[]> {
  const { json } = await SupersetClient.get({
    endpoint: '/api/v1/database/?q=(columns:!(id,database_name))',
  });
  return json.result ?? [];
}

/** Upload an Excel/CSV file and stage it as a dataset (Data Modeler). */
export async function uploadExcel(
  databaseId: number,
  file: File,
  tableName?: string,
): Promise<UploadResult> {
  const formData = new FormData();
  formData.append('database_id', String(databaseId));
  formData.append('file', file);
  if (tableName) formData.append('table_name', tableName);
  const { json } = await SupersetClient.post({
    endpoint: `${BASE}/upload/`,
    postPayload: formData,
  });
  return json;
}
