{{/*
Full name
*/}}
{{- define "batch.fullname" -}}
{{- .Values.commonValues.fullnameOverride | default .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "batch.labels" -}}
{{- if .Values.commonValues.labels }}
{{- toYaml .Values.commonValues.labels | nindent 0 }}
{{- end -}}
{{- if .Values.commonValues.global.env }}
{{- if .Values.commonValues.labels }}
{{- printf "\n" -}}
{{- end -}}
tags.datadoghq.com/env: {{ .Values.commonValues.global.env | quote }}
tags.datadoghq.com/service: {{ include "batch.fullname" . }}
tags.datadoghq.com/version: {{ .Values.commonValues.image.tag | quote }}
{{- end -}}
{{- end }}

{{/*
Pod template labels
*/}}
{{- define "batch.podLabels" -}}
{{- if .Values.commonValues.podLabels }}
{{- toYaml .Values.commonValues.podLabels | nindent 0 }}
{{- end -}}
{{- if .Values.commonValues.global.env }}
{{- if .Values.commonValues.podLabels }}
{{- printf "\n" -}}
{{- end -}}
tags.datadoghq.com/env: {{ .Values.commonValues.global.env | quote }}
tags.datadoghq.com/service: {{ include "batch.fullname" . }}
tags.datadoghq.com/version: {{ .Values.commonValues.image.tag | quote }}
{{- end -}}
{{- end }}

{{/*
이미지 정보
*/}}
{{- define "batch.image" -}}
{{- $common := .Values.commonValues }}
{{- if $common.image.registry -}}
{{- printf "%s/%s:%s" $common.image.registry $common.image.repository ($common.image.tag | default .Chart.AppVersion) -}}
{{- else if $common.global.registry -}}
{{- printf "%s.dkr.ecr.%s.amazonaws.com/%s:%s" $common.global.registry.accountId $common.global.registry.region $common.image.repository ($common.image.tag | default .Chart.AppVersion) -}}
{{- else -}}
{{- printf "%s:%s" $common.image.repository ($common.image.tag | default .Chart.AppVersion) -}}
{{- end -}}
{{- end }}

{{/*
환경 변수 - AWS
*/}}
{{- define "batch.awsEnv" -}}
{{- if .Values.commonValues.aws.enabled }}
- name: AWS_REGION
  value: {{ .Values.commonValues.aws.region | default "ap-northeast-2" }}
{{- if .Values.commonValues.aws.credentials.fromSecret }}
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ .Values.commonValues.aws.credentials.secretName | default "aws-account" }}
      key: {{ .Values.commonValues.aws.credentials.accessKeyIdKey | default "AWS_ACCESS_KEY_ID" }}
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.commonValues.aws.credentials.secretName | default "aws-account" }}
      key: {{ .Values.commonValues.aws.credentials.secretAccessKeyKey | default "AWS_SECRET_ACCESS_KEY" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
환경 변수 - 전체
*/}}
{{- define "batch.env" -}}
{{- include "batch.awsEnv" . -}}
{{- if .Values.commonValues.env }}
{{- toYaml .Values.commonValues.env -}}
{{- end -}}
{{- end }}

{{/*
볼륨 마운트 - 전체
*/}}
{{- define "batch.volumeMounts" -}}
{{- if .Values.commonValues.volumeMounts }}
{{- toYaml .Values.commonValues.volumeMounts }}
{{- end -}}
{{- end }}

{{/*
볼륨 - 전체
*/}}
{{- define "batch.volumes" -}}
{{- if .Values.commonValues.volumes }}
{{- toYaml .Values.commonValues.volumes }}
{{- end -}}
{{- end }}

{{/*
Node Selector
*/}}
{{- define "batch.nodeSelector" -}}
{{- if .Values.commonValues.nodeSelector }}
nodeSelector:
  {{- toYaml .Values.commonValues.nodeSelector | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Affinity
*/}}
{{- define "batch.affinity" -}}
{{- if .Values.commonValues.affinity }}
affinity:
  {{- toYaml .Values.commonValues.affinity | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Tolerations
*/}}
{{- define "batch.tolerations" -}}
{{- if .Values.commonValues.tolerations }}
tolerations:
  {{- toYaml .Values.commonValues.tolerations | nindent 2 }}
{{- end }}
{{- end }}