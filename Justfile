gen-api-client openapi_url="https://api.satsapp.link/api-docs/openapi.json":
	curl -sSL {{openapi_url}} -o openapi.json
	openapi-generator-cli generate -i openapi.json -g dart-dio -o api_client --additional-properties=pubName=api_client,pubVersion=1.0.0
	cd api_client && flutter pub run build_runner build --delete-conflicting-outputs

run:
	flutter run --dart-define-from-file=.env
