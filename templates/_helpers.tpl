{{- define "app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "app.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "app.name" . -}}
{{- end -}}
{{- end -}}

{{- define "app.labels" -}}
app.kubernetes.io/name: {{ include "app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app: {{ .Values.labels.app | default (include "app.name" .) }}
{{- end -}}

{{- define "app.selectorLabels" -}}
app: {{ .Values.labels.app | default (include "app.name" .) }}
{{- end -}}

{{- define "app.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | toString) -}}
{{- end -}}
