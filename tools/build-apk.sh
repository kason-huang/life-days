#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
toolchains_dir="$(dirname "$project_dir")/.toolchains"
export ANDROID_HOME="${ANDROID_HOME:-$toolchains_dir/android-sdk}"
if [[ -z "${JAVA_HOME:-}" ]]; then
  for jdk_dir in "$toolchains_dir"/zulu*/Contents/Home; do
    if [[ -x "$jdk_dir/bin/java" ]]; then export JAVA_HOME="$jdk_dir"; break; fi
  done
fi
export FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.googleapis.com}"
export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}"
if [[ "${LIFE_DAYS_DIRECT:-0}" == 1 ]]; then
  unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
  export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djava.net.useSystemProxies=false -Dhttp.proxyHost= -Dhttps.proxyHost= -DsocksProxyHost= -Dhttp.nonProxyHosts=* -Dorg.gradle.internal.http.socketTimeout=20000 -Dorg.gradle.internal.http.connectionTimeout=10000"
fi
cd "$project_dir"
exec "$toolchains_dir/flutter/bin/flutter" --verbose build apk --release "$@"
