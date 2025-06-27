get-api-spec:
	curl -o openapi.json https://api.satsapp.link/api-doc/openapi.json

gen-api-client:
	openapi-generator-cli generate -i openapi.json -g dart-dio -o api_client --additional-properties=pubName=api_client,pubVersion=1.0.0
	cd api_client && flutter pub run build_runner build --delete-conflicting-outputs

run:
	flutter run --dart-define-from-file=.env
