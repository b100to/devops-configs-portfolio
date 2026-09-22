{{/*
애플리케이션 이름
*/}}
{{- define "app.name" -}}
{{- .Values.name | default .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
전체 이름 (Full name)
*/}}
{{- define "app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart 이름과 버전
*/}}
{{- define "app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
공통 레이블
*/}}
{{- define "app.labels" -}}
helm.sh/chart: {{ include "app.chart" . }}
{{ include "app.selectorLabels" . }}
{{- if .Values.image.tag }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
{{- else if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.appComponent }}
app.kubernetes.io/component: {{ .Values.appComponent | quote }}
{{- end }}
{{- if .Values.appPartOf }}
app.kubernetes.io/part-of: {{ .Values.appPartOf | quote }}
{{- end }}
{{- if .Values.labels }}
{{- toYaml .Values.labels | nindent 0 }}
{{- end }}
{{- if .Values.datadog.enabled }}
tags.datadoghq.com/env: {{ .Values.global.env | default .Values.env | quote }}
tags.datadoghq.com/service: {{ include "app.fullname" . }}
tags.datadoghq.com/version: {{ .Values.datadog.version | default .Values.image.tag | quote }}
{{- end }}
{{- end }}

{{/*
셀렉터 레이블
*/}}
{{- define "app.selectorLabels" -}}
app: {{ include "app.fullname" . }}
app.kubernetes.io/name: {{ include "app.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Pod 템플릿 레이블
*/}}
{{- define "app.podLabels" -}}
{{ include "app.selectorLabels" . }}
{{- if .Values.podLabels }}
{{- toYaml .Values.podLabels | nindent 0 }}
{{- end }}
{{- if .Values.datadog.enabled }}
tags.datadoghq.com/env: {{ .Values.global.env | default .Values.env | quote }}
tags.datadoghq.com/service: {{ include "app.fullname" . }}
tags.datadoghq.com/version: {{ .Values.datadog.version | default .Values.image.tag | quote }}
{{- end }}
{{- end }}

{{/*
Service Account 이름
*/}}
{{- define "app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
이미지 정보
*/}}
{{- define "app.image" -}}
{{- if .Values.image.registry -}}
{{- printf "%s/%s:%s" .Values.image.registry .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- else if .Values.global.registry -}}
{{- printf "%s.dkr.ecr.%s.amazonaws.com/%s:%s" .Values.global.registry.accountId .Values.global.registry.region .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}
{{- end }}

{{/*
환경 변수 - Datadog
*/}}
{{- define "app.datadogEnv" -}}
{{- if .Values.datadog.enabled }}
- name: DD_LOGS_INJECTION
  value: {{ .Values.datadog.logsInjection | default "true" | quote }}
- name: DD_TRACE_SAMPLE_RATE
  value: {{ .Values.datadog.traceSampleRate | default "0.1" | quote }}
- name: DD_TRACE_AGENT_URL
  value: {{ .Values.datadog.traceAgentUrl | default "unix:///var/run/datadog/apm.socket" | quote }}
- name: DD_ENV
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: 'metadata.labels[''tags.datadoghq.com/env'']'
- name: DD_SERVICE
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: 'metadata.labels[''tags.datadoghq.com/service'']'
- name: DD_VERSION
  valueFrom:
    fieldRef:
      apiVersion: v1
      fieldPath: 'metadata.labels[''tags.datadoghq.com/version'']'
{{- end }}
{{- end }}

{{/*
환경 변수 - AWS
AWS credentials는 envFrom으로 주입 (IRSA 또는 Access Key 방식 모두 지원)
*/}}
{{- define "app.awsEnv" -}}
{{- if .Values.aws.enabled -}}
- name: AWS_DEFAULT_REGION
  value: {{ .Values.aws.region | default "ap-northeast-2" }}
- name: AWS_REGION
  value: {{ .Values.aws.region | default "ap-northeast-2" }}
{{- end }}
{{- end }}

{{/*
환경 변수 - 전체
*/}}
{{- define "app.env" -}}
{{- include "app.awsEnv" . }}
{{- include "app.datadogEnv" . }}
{{- if .Values.env }}
{{ toYaml .Values.env }}
{{- end }}
{{- end }}

{{/*
볼륨 마운트 - Datadog
*/}}
{{- define "app.datadogVolumeMounts" -}}
{{- if .Values.datadog.enabled -}}
- name: apmsocketpath
  mountPath: /var/run/datadog
{{- end }}
{{- end }}

{{/*
볼륨 마운트 - 전체
*/}}
{{- define "app.volumeMounts" -}}
{{- include "app.datadogVolumeMounts" . }}
{{- if .Values.volumeMounts }}
{{ toYaml .Values.volumeMounts }}
{{- end }}
{{- end }}

{{/*
볼륨 - Datadog
*/}}
{{- define "app.datadogVolumes" -}}
{{- if .Values.datadog.enabled -}}
- name: apmsocketpath
  hostPath:
    path: /var/run/datadog/
    type: ''
{{- end }}
{{- end }}

{{/*
볼륨 - 전체
*/}}
{{- define "app.volumes" -}}
{{- include "app.datadogVolumes" . }}
{{- if .Values.volumes }}
{{ toYaml .Values.volumes }}
{{- end }}
{{- end }}

{{/*
Topology Spread Constraints
*/}}
{{- define "app.topologySpreadConstraints" -}}
{{- if .Values.topologySpreadConstraints }}
{{- toYaml .Values.topologySpreadConstraints }}
{{- else if .Values.defaultTopologySpread.enabled }}
- maxSkew: 1
  topologyKey: topology.kubernetes.io/zone
  whenUnsatisfiable: ScheduleAnyway
  labelSelector:
    matchLabels:
      {{- include "app.selectorLabels" . | nindent 6 }}
- maxSkew: 1
  topologyKey: kubernetes.io/hostname
  whenUnsatisfiable: ScheduleAnyway
  labelSelector:
    matchLabels:
      {{- include "app.selectorLabels" . | nindent 6 }}
{{- end }}
{{- end }}

{{/*
Node Selector
*/}}
{{- define "app.nodeSelector" -}}
{{- if .Values.nodeSelector }}
nodeSelector:
  {{- toYaml .Values.nodeSelector | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Affinity
*/}}
{{- define "app.affinity" -}}
{{- if .Values.affinity }}
affinity:
  {{- toYaml .Values.affinity | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Tolerations
*/}}
{{- define "app.tolerations" -}}
{{- if .Values.tolerations }}
tolerations:
  {{- toYaml .Values.tolerations | nindent 0 }}
{{- end }}
{{- end }}

{{/*
Priority Class Name
*/}}
{{- define "app.priorityClassName" -}}
{{- if .Values.priorityClassName -}}
priorityClassName: {{ .Values.priorityClassName }}
{{- end }}
{{- end }}
