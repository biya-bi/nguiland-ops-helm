{{- define "artifactory-common.config" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "artifactory-common.fullname" . }}-config
  labels:
    {{- include "artifactory-common.labels" . | nindent 4 }}
data:
  artifactory.config.import.yml: |
    GeneralConfiguration:
      eula:
        accepted: true
    OnboardingConfiguration:
      repoTypes:
{{ toYaml .Values.repoTypes | indent 8 }}
{{- end }}