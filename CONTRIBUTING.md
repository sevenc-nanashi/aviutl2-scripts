# 開発者向けメモ

このリポジトリは[aviutl2-aulua](https://github.com/karoterra/aviutl2-aulua)と[lefthook](https://github.com/evilmartians/lefthook)を使用しています。
`mise install`で依存関係をインストールできます。

- `mise run build`：スクリプトをビルドします。
- `mise run dev`：スクリプトを監視し、変更があった場合に自動でビルドします。
- `mise run format`：コードフォーマットを実行します。
- `mise run lint`：コードリントを実行します。

- `rake install_demo[script_dir]`：デモプロジェクトをAviUtlのScriptフォルダにインストールします。（引数でフォルダを指定できます）
