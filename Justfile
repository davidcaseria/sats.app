build target:
	flutter build {{target}} --dart-define-from-file=.env

get-api-spec url="https://api.satsapp.link/api-doc/openapi.json":
	curl -o openapi.json {{url}}

gen-api-client:
	openapi-generator-cli generate -i openapi.json -g dart-dio -o api_client --additional-properties=pubName=api_client,pubVersion=1.0.0
	cd api_client && dart run build_runner build --delete-conflicting-outputs

run:
	flutter run --dart-define-from-file=.env
