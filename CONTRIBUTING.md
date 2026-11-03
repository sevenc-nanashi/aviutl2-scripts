# 開発者向けメモ

このリポジトリは[aviutl2-aulua](https://github.com/karoterra/aviutl2-aulua)と[lefthook](https://github.com/evilmartians/lefthook)を使用しています。
`mise install`で依存関係をインストールできます。

- `aviutl2 dev`：開発環境を構築します。
- `mise run build`：スクリプトをビルドします。
- `mise run dev`：スクリプトを監視し、変更があった場合に自動でビルドします。
- `mise run format`：コードフォーマットを実行します。
- `mise run lint`：コードリントを実行します。

## 翻訳

翻訳は各スクリプトの`i18n.yaml`を編集します。`.aul2`は直接編集せず、`rake build:i18n`で`extra/Language`に生成してください。

```yaml
English:
  セクション名:
    翻訳元: Translation
```

## 追加ファイル

各スクリプトの`extra`配下のファイルは、ディレクトリ構成を保ってau2pkgのルートに同梱されます。
例えば`extra/Language/English.example-anm2.aul2`は`Language/English.example-anm2.aul2`に配置されます。
言語ファイル以外のファイルやサブディレクトリも同梱できます。
