# Download Server

<https://github.com/sevenc-nanashi/aviutl2-scripts> にあるスクリプトをダウンロードするためのサーバー。

## API

### `GET /:scriptName`

`scriptName`に対応するスクリプトをダウンロードします。
`X-Script-Version`にバージョン、`X-Script-Commit`にコミットハッシュが含まれたレスポンスヘッダーが返されます。

#### クエリパラメーター

- `version`：スクリプトのバージョンを指定します。`latest`または`x.x`の形式で指定できます。省略した場合は最新バージョンがダウンロードされます。
- `type`：ダウンロードするデータを指定します。`script`（スクリプトファイル）、`releases`（リリース情報）、`au2pkg`（.au2pkg.zipファイル）から選択できます。省略した場合は`script`がダウンロードされます。
