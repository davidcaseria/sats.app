gen-api-client:
	openapi-generator-cli generate -i openapi.json -g dart-dio -o api_client --additional-properties=pubName=api_client,pubVersion=1.0.0
run:
	flutter run --dart-define-from-file=.env
