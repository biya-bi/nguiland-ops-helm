{{/*
Expand the name of the chart.
*/}}
{{- define "ingress-ip-discoverer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ingress-ip-discoverer.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "ingress-ip-discoverer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ingress-ip-discoverer.labels" -}}
helm.sh/chart: {{ include "ingress-ip-discoverer.chart" . }}
{{ include "ingress-ip-discoverer.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ingress-ip-discoverer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ingress-ip-discoverer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ingress-ip-discoverer.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ingress-ip-discoverer.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{/*
Common Pod template used by the discovery Job and CronJob.
*/}}
{{- define "ingress-ip-discoverer.podTemplate" -}}
{{- $repository := .Values.image.repository | trim -}}
{{- $image := $repository -}}
{{- if .Values.image.digest -}}
  {{- $digest := .Values.image.digest | trim -}}
  {{- $image = printf "%s@%s" $repository $digest -}}
{{- else -}}
  {{- $tag := .Values.image.tag | trim -}}
  {{- $image = printf "%s:%s" $repository $tag -}}
{{- end -}}
{{- $pullPolicy := .Values.image.pullPolicy | default "IfNotPresent" -}}

metadata:
  labels:
    {{- include "ingress-ip-discoverer.selectorLabels" . | nindent 4 }}
spec:
  serviceAccountName: {{ include "ingress-ip-discoverer.serviceAccountName" . }}
  {{- with .Values.podSecurityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  restartPolicy: Never
  containers:
    - name: {{ .Chart.Name }}
      image: {{ $image | quote }}
      imagePullPolicy: {{ $pullPolicy | quote }}
      {{- with .Values.securityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.resources }}
      resources:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      env:
        {{- range $name, $value := .Values.envMap }}
        - name: {{ $name | quote }}
          value: {{ tpl ($value | toString) $ | quote }}
        {{- end }}
        {{- with .Values.env }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      command:
        - /bin/sh
        - -c
      args:
        - |-
          {{- .Files.Get "scripts/discover.sh" | nindent 10 }}
{{- end }}
