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
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useHistory, useParams } from 'react-router-dom';
import { t } from '@apache-superset/core/translation';
import { styled } from '@apache-superset/core/theme';
import {
  Button,
  Collapse,
  Input,
  Modal,
  Select,
  Space,
  Loading,
  Tag,
  Typography,
  Upload,
} from '@superset-ui/core/components';
import { Icons } from '@superset-ui/core/components/Icons';
import { useToasts } from 'src/components/MessageToasts/withToasts';
import SubMenu from 'src/features/home/SubMenu';
import {
  createReport,
  fetchDatabases,
  fetchDatasets,
  fetchReport,
  previewReport,
  updateReport,
  exportPdfUrl,
  exportReportUrl,
  exportXlsxUrl,
  uploadExcel,
} from './api';
import {
  DatasetOption,
  DatabaseOption,
  EMPTY_DEFINITION,
  FieldRef,
  MetricRef,
  PreviewResult,
  ReportDefinition,
} from './types';
import DatasetPanel from './components/DatasetPanel';
import FieldsPanel from './components/FieldsPanel';
import FiltersPanel from './components/FiltersPanel';
import RelationshipsPanel from './components/RelationshipsPanel';
import PreviewPanel from './components/PreviewPanel';

const { Panel } = Collapse;

const StyledLayout = styled.div`
  ${({ theme }) => `
    display: grid;
    /* minmax(0, 1fr) lets the report canvas column shrink below its content
       width, so wide preview tables scroll inside the pane instead of
       stretching the page. */
    grid-template-columns: 340px minmax(0, 1fr);
    gap: ${theme.sizeUnit * 4}px;
    padding: ${theme.sizeUnit * 4}px;
    align-items: start;
  `}
`;

const StyledCanvas = styled.div`
  min-width: 0;
  overflow: hidden;
`;

const StyledLeft = styled.div`
  position: sticky;
  top: ${({ theme }) => theme.sizeUnit * 4}px;
  max-height: calc(100vh - 160px);
  overflow: auto;
`;

const StyledToolbar = styled.div`
  ${({ theme }) => `
    display: flex;
    align-items: center;
    gap: ${theme.sizeUnit * 2}px;
    margin-bottom: ${theme.sizeUnit * 3}px;
    flex-wrap: wrap;
  `}
`;

const StyledMeta = styled.div`
  ${({ theme }) => `
    display: flex;
    align-items: center;
    gap: ${theme.sizeUnit * 2}px;
    flex: 1;
    min-width: 320px;
  `}
`;

export default function ReportDesignerPage() {
  const history = useHistory();
  const { reportId } = useParams<{ reportId?: string }>();
  const { addDangerToast, addSuccessToast } = useToasts();

  const [datasets, setDatasets] = useState<DatasetOption[]>([]);
  const [datasetsLoaded, setDatasetsLoaded] = useState(false);
  const [loadingReport, setLoadingReport] = useState(Boolean(reportId));

  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [definition, setDefinition] =
    useState<ReportDefinition>(EMPTY_DEFINITION);

  const [saving, setSaving] = useState(false);
  const [previewLoading, setPreviewLoading] = useState(false);
  const [previewResult, setPreviewResult] = useState<PreviewResult | null>(null);
  const [previewError, setPreviewError] = useState<string | null>(null);

  // ---- Data Modeler (Excel upload) -------------------------------------
  const [uploadOpen, setUploadOpen] = useState(false);
  const [uploadDatabase, setUploadDatabase] = useState<number | undefined>();
  const [uploadFile, setUploadFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);
  const [databases, setDatabases] = useState<DatabaseOption[]>([]);

  // ---- load datasets -------------------------------------------------
  useEffect(() => {
    fetchDatasets()
      .then(list => setDatasets(list))
      .catch(() => addDangerToast(t('Failed to load datasets')))
      .finally(() => setDatasetsLoaded(true));
  }, [addDangerToast]);

  // ---- load report definition ----------------------------------------
  useEffect(() => {
    if (!reportId) {
      setLoadingReport(false);
      return;
    }
    setLoadingReport(true);
    fetchReport(Number(reportId))
      .then(report => {
        setName(report.name);
        setDescription(report.description);
        setDefinition({
          ...EMPTY_DEFINITION,
          ...report.definition,
        });
      })
      .catch(() => addDangerToast(t('Failed to load report')))
      .finally(() => setLoadingReport(false));
  }, [reportId, addDangerToast]);

  // ---- definition helpers ----------------------------------------------
  const updateDefinition = useCallback((patch: Partial<ReportDefinition>) => {
    setDefinition(prev => ({ ...prev, ...patch }));
  }, []);

  const handleSelectDataset = useCallback(
    (id: number) => {
      const current = definition.datasets;
      if (current.some(ds => ds.id === id)) return;
      const alias = `d${current.length + 1}`;
      updateDefinition({ datasets: [...current, { id, alias }] });
    },
    [definition.datasets, updateDefinition],
  );

  const handleAddColumn = useCallback(
    (field: FieldRef) => {
      const exists = definition.columns.some(
        item => item.dataset === field.dataset && item.column === field.column,
      );
      if (exists) return;
      updateDefinition({ columns: [...definition.columns, field] });
    },
    [definition.columns, updateDefinition],
  );

  const handleAddGroup = useCallback(
    (field: FieldRef) => {
      const exists = definition.group_by.some(
        item => item.dataset === field.dataset && item.column === field.column,
      );
      if (exists) return;
      updateDefinition({ group_by: [...definition.group_by, field] });
    },
    [definition.group_by, updateDefinition],
  );

  const handleAddMetric = useCallback(
    (metric: MetricRef) => {
      const exists = definition.metrics.some(
        item =>
          item.dataset === metric.dataset &&
          item.column === metric.column &&
          item.aggregate === metric.aggregate,
      );
      if (exists) return;
      updateDefinition({ metrics: [...definition.metrics, metric] });
    },
    [definition.metrics, updateDefinition],
  );

  // ---- order by ---------------------------------------------------------
  const orderByOptions = useMemo(() => {
    const items: Array<{ label: string; value: string }> = [];
    definition.columns.forEach(field => {
      items.push({
        label: `${field.label} (${field.column})`,
        value: `${field.dataset}:${field.column}`,
      });
    });
    definition.metrics.forEach(metric => {
      items.push({
        label: `${metric.label}`,
        value: `${metric.dataset}:${metric.column}:${metric.aggregate}:${metric.label}`,
      });
    });
    return items;
  }, [definition.columns, definition.metrics]);

  const handleAddOrder = (value: string) => {
    const [dataset, column, , ...rest] = value.split(':');
    const label = rest.length > 0 ? rest.join(':') : undefined;
    const entry = {
      dataset: Number(dataset),
      column,
      desc: false,
      ...(label ? { label } : {}),
    };
    const exists = definition.order_by.some(
      item =>
        item.dataset === entry.dataset && item.column === entry.column,
    );
    if (exists) return;
    updateDefinition({ order_by: [...definition.order_by, entry] });
  };

  // ---- save / preview ----------------------------------------------------
  const handleSave = () => {
    setSaving(true);
    const definitionJson: ReportDefinition = {
      ...definition,
      datasets: definition.datasets.map((ds, index) => ({
        ...ds,
        alias: ds.alias || `d${index + 1}`,
      })),
    };
    const action = reportId
      ? updateReport(Number(reportId), name, description, definitionJson)
      : createReport(name, description, definitionJson);
    action
      .then(saved => {
        addSuccessToast(t('Report saved'));
        if (!reportId) {
          history.replace(`/reportdesigner/designer/${saved.id}/`);
        }
      })
      .catch(() => addDangerToast(t('Failed to save report')))
      .finally(() => setSaving(false));
  };

  const handlePreview = () => {
    setPreviewLoading(true);
    setPreviewError(null);
    previewReport(definition)
      .then(result => setPreviewResult(result))
      .catch(err => {
        const message =
          (err as { message?: string })?.message || t('Preview failed');
        setPreviewError(message);
        setPreviewResult(null);
      })
      .finally(() => setPreviewLoading(false));
  };

  // ---- Data Modeler handlers ---------------------------------------------
  const openUpload = () => {
    fetchDatabases()
      .then(list => setDatabases(list))
      .catch(() => addDangerToast(t('Failed to load databases')));
    setUploadDatabase(undefined);
    setUploadFile(null);
    setUploadOpen(true);
  };

  const handleUpload = () => {
    if (uploadDatabase === undefined || !uploadFile) return;
    setUploading(true);
    uploadExcel(uploadDatabase, uploadFile)
      .then(result => {
        addSuccessToast(
          `Uploaded ${result.rows} rows as ${result.table_name}`,
        );
        setUploadOpen(false);
        // Refresh datasets so the new table is available in the picker.
        fetchDatasets()
          .then(list => {
            setDatasets(list);
            handleSelectDataset(result.dataset_id);
          })
          .catch(() => addDangerToast(t('Failed to refresh datasets')));
      })
      .catch(err => {
        const message =
          (err as { message?: string })?.message || t('Upload failed');
        addDangerToast(message);
      })
      .finally(() => setUploading(false));
  };

  if (loadingReport) {
    return (
      <div style={{ textAlign: 'center', padding: 80 }}>
        <Loading position="floating" />
      </div>
    );
  }

  return (
    <>
      <SubMenu
        name={t('Report Designer')}
        buttons={[
          {
            name: t('Back to reports'),
            onClick: () => history.push('/reportdesigner/list/'),
            buttonStyle: 'link',
          },
          {
            name: t('Run preview'),
            onClick: handlePreview,
            buttonStyle: 'secondary',
            loading: previewLoading,
            icon: <Icons.PlayCircleOutlined />,
          },
          {
            name: t('Save'),
            onClick: handleSave,
            buttonStyle: 'primary',
            loading: saving,
            icon: <Icons.SaveOutlined />,
          },
        ]}
      />
      <StyledLayout>
        <StyledLeft>
          <DatasetPanel
            datasets={datasets}
            selectedDatasetIds={definition.datasets.map(ds => ds.id)}
            onSelectDataset={handleSelectDataset}
          />
        </StyledLeft>

        <StyledCanvas>
          <StyledToolbar>
            <StyledMeta>
              <Input
                placeholder={t('Report name')}
                value={name}
                onChange={event => setName(event.target.value)}
                style={{ maxWidth: 360 }}
              />
              <Input
                placeholder={t('Description (optional)')}
                value={description}
                onChange={event => setDescription(event.target.value)}
                style={{ maxWidth: 360 }}
              />
            </StyledMeta>
            <Space wrap>
              <Typography.Text>{t('Limit')}</Typography.Text>
              <Select
                value={definition.limit}
                style={{ width: 100 }}
                options={[100, 500, 1000, 5000, 10000].map(value => ({
                  label: String(value),
                  value,
                }))}
                onChange={(value: number) =>
                  updateDefinition({ limit: value })
                }
              />
              {reportId && (
                <>
                  <Button
                    icon={<Icons.DownloadOutlined />}
                    href={exportReportUrl(Number(reportId))}
                    target="_blank"
                    rel="noreferrer"
                  >
                    {t('CSV')}
                  </Button>
                  <Button
                    icon={<Icons.FileOutlined />}
                    href={exportXlsxUrl(Number(reportId))}
                    target="_blank"
                    rel="noreferrer"
                  >
                    {t('Excel')}
                  </Button>
                  <Button
                    icon={<Icons.ProfileOutlined />}
                    href={exportPdfUrl(Number(reportId))}
                    target="_blank"
                    rel="noreferrer"
                  >
                    {t('PDF')}
                  </Button>
                </>
              )}
              <Button
                icon={<Icons.UploadOutlined />}
                onClick={openUpload}
              >
                {t('Upload Excel')}
              </Button>
            </Space>
          </StyledToolbar>

          {!datasetsLoaded ? (
            <Loading position="floating" />
          ) : (
            <>
              {definition.datasets.length === 0 && (
                <Tag color="orange" style={{ marginBottom: 12 }}>
                  {t('Add at least one dataset from the left panel to start.')}
                </Tag>
              )}

              <Collapse
                defaultActiveKey={['relationships', 'fields', 'filters']}
                bordered
              >
                <Panel
                  key="datasets"
                  header={
                    <Space size={4}>
                      <Icons.DatabaseOutlined />
                      {t('Datasets')}
                      <Tag>{definition.datasets.length}</Tag>
                    </Space>
                  }
                >
                  <Space wrap>
                    {definition.datasets.map(ds => {
                      const meta = datasets.find(item => item.id === ds.id);
                      return (
                        <Tag
                          key={ds.id}
                          color="blue"
                          closable
                          onClose={() =>
                            updateDefinition({
                              datasets: definition.datasets.filter(
                                item => item.id !== ds.id,
                              ),
                            })
                          }
                        >
                          {meta?.table_name ?? `#${ds.id}`} ({ds.alias})
                        </Tag>
                      );
                    })}
                  </Space>
                </Panel>

                <Panel
                  key="relationships"
                  header={
                    <Space size={4}>
                      <Icons.LinkOutlined />
                      {t('Relationships')}
                      <Tag>{definition.relationships.length}</Tag>
                    </Space>
                  }
                >
                  <RelationshipsPanel
                    datasets={datasets.filter(ds =>
                      definition.datasets.some(item => item.id === ds.id),
                    )}
                    relationships={definition.relationships}
                    onChange={relationships =>
                      updateDefinition({ relationships })
                    }
                  />
                </Panel>

                <Panel
                  key="fields"
                  header={
                    <Space size={4}>
                      <Icons.Sigma />
                      {t('Fields')}
                      <Tag>{definition.columns.length}</Tag>
                    </Space>
                  }
                >
                  <FieldsPanel
                    datasets={datasets}
                    columns={definition.columns}
                    groupBy={definition.group_by}
                    metrics={definition.metrics}
                    onAddColumn={handleAddColumn}
                    onRemoveColumn={index =>
                      updateDefinition({
                        columns: definition.columns.filter(
                          (_, i) => i !== index,
                        ),
                      })
                    }
                    onUpdateColumnLabel={(index, label) =>
                      updateDefinition({
                        columns: definition.columns.map((field, i) =>
                          i === index ? { ...field, label } : field,
                        ),
                      })
                    }
                    onAddGroup={handleAddGroup}
                    onRemoveGroup={index =>
                      updateDefinition({
                        group_by: definition.group_by.filter(
                          (_, i) => i !== index,
                        ),
                      })
                    }
                    onAddMetric={handleAddMetric}
                    onRemoveMetric={index =>
                      updateDefinition({
                        metrics: definition.metrics.filter(
                          (_, i) => i !== index,
                        ),
                      })
                    }
                    onUpdateMetric={(index, metric) =>
                      updateDefinition({
                        metrics: definition.metrics.map((item, i) =>
                          i === index ? metric : item,
                        ),
                      })
                    }
                  />

                  <div style={{ marginTop: 16 }}>
                    <Space align="center">
                      <Typography.Text strong>
                        {t('Order by')}
                      </Typography.Text>
                      <Select
                        placeholder={t('Add ordering…')}
                        style={{ width: 260 }}
                        showSearch
                        options={orderByOptions}
                        onChange={handleAddOrder}
                      />
                    </Space>
                    <Space wrap style={{ marginTop: 8 }}>
                      {definition.order_by.map((entry, index) => (
                        <Tag
                          key={`${entry.dataset}-${entry.column}-${index}`}
                          color="cyan"
                          closable
                          onClose={() =>
                            updateDefinition({
                              order_by: definition.order_by.filter(
                                (_, i) => i !== index,
                              ),
                            })
                          }
                        >
                          {entry.column}{' '}
                          {entry.desc ? t('desc') : t('asc')}
                        </Tag>
                      ))}
                    </Space>
                  </div>
                </Panel>

                <Panel
                  key="filters"
                  header={
                    <Space size={4}>
                      <Icons.FilterOutlined />
                      {t('Filters')}
                      <Tag>{definition.filters.length}</Tag>
                    </Space>
                  }
                >
                  <FiltersPanel
                    datasets={datasets.filter(ds =>
                      definition.datasets.some(item => item.id === ds.id),
                    )}
                    filters={definition.filters}
                    onChange={filters => updateDefinition({ filters })}
                  />
                </Panel>
              </Collapse>

              <PreviewPanel
                result={previewResult}
                loading={previewLoading}
                error={previewError}
                onRefresh={handlePreview}
              />
            </>
          )}
        </StyledCanvas>
      </StyledLayout>

      <Modal
        open={uploadOpen}
        title={t('Upload Excel / CSV as a dataset')}
        onCancel={() => setUploadOpen(false)}
        onOk={handleUpload}
        okText={t('Upload')}
        confirmLoading={uploading}
        okButtonProps={{ disabled: uploadDatabase === undefined || !uploadFile }}
      >
        <Space direction="vertical" style={{ width: '100%' }}>
          <div>
            <Typography.Text strong>{t('Target database')}</Typography.Text>
            <Select
              placeholder={t('Select a writable database…')}
              options={databases.map(db => ({
                label: db.database_name,
                value: db.id,
              }))}
              value={uploadDatabase ?? null}
              style={{ width: '100%', marginTop: 4 }}
              onChange={setUploadDatabase}
            />
            <Typography.Text type="secondary" style={{ fontSize: 12 }}>
              {t('Note: the read replica is read-only — pick a writable '
                + 'connection so the staging table can be created.')}
            </Typography.Text>
          </div>
          <Upload
            beforeUpload={file => {
              setUploadFile(file);
              return false;
            }}
            onRemove={() => setUploadFile(null)}
            maxCount={1}
            accept=".xlsx,.xls,.csv"
          >
            <Button icon={<Icons.UploadOutlined />}>
              {t('Choose file')}
            </Button>
          </Upload>
        </Space>
      </Modal>
    </>
  );
}
