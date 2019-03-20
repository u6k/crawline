# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- [#6759: データに付加情報を添付して保存する](https://redmine.u6k.me/issues/6759)
- [#6846: S3ストレージにサフィックスを付与して格納する](https://redmine.u6k.me/issues/6846)

これらの変更により、過去バージョンのデータは非互換になります。

## [0.7 1] - 2019-03-13

### Fixed

- [#6838: クロール中にエラーが発生する](https://redmine.u6k.me/issues/6838)

## [0.7.0] - 2019-03-11

### Added

- [#6767: クロールやパースのときに、残数がわかるようにする](https://redmine.u6k.me/issues/6767)

## [0.6.0] - 2019-03-08

### Changed

- [#6830: インターバルを、実際にダウンロードした場合のみ設定する](https://redmine.u6k.me/issues/6830)

## [0.5.0] - 2019-02-25

### Changed

- [#6814: 再ダウンロードをしない場合でもクロールする](https://redmine.u6k.me/issues/6814)

## [0.4.0] - 2019-02-25

### Added

- [#6766: クローリングのインターバルを設定する](https://redmine.u6k.me/issues/6766)
    - デフォルトのインターバル時間は1秒です

## [0.3.0] - 2019-01-31

### Added

- [#6750: ルールを定義して、crawlineのエンジンに処理を任せる方式に変更する](https://redmine.u6k.me/issues/6750)
    - ベース・パーサー、エンジンを実装しました
- [#6746: デバッグ・ログを出力する](https://redmine.u6k.me/issues/6746)
    - デフォルトはINFOレベルです
    - CRAWLINE_LOGGER_LEVEL環境変数でログ・レベルを設定できます

## [0.2.5] - 2019-01-24

### Fixed

- [#6748: SSL通信に対応する](https://redmine.u6k.me/issues/6748)
- [#6749: リダイレクトにおいてLocationヘッダーにパスのみ指定された場合に対応する](https://redmine.u6k.me/issues/6749)

## [0.2.4] - 2019-01-24

### Added

- [#6747: S3オブジェクトが存在するか調べるメソッドを実装する](https://redmine.u6k.me/issues/6747)

## [0.2.3] - 2019-01-24

### Fixed

- [requireが不足していたために呼び出すとエラーになる](https://redmine.u6k.me/issues/6735)

## [0.2.2] - 2019-01-24

### Added

- [共通処理をcrawlineに切り出して、crawlineベースで再実装する](https://redmine.u6k.me/issues/6735)
    - `get_s3_object`メソッドで、指定したS3オブジェクトが存在しない場合に`nil`を返すようにしました

## [0.2.1] - 2019-01-23

### Added

- [共通処理をcrawlineに切り出して、crawlineベースで再実装する](https://redmine.u6k.me/issues/6735)
    - `remove_s3_objects`メソッドを追加しました
    - S3バケット内のすべてのオブジェクトを削除する機会は、思ったより多いです…

## [0.2.0] - 2019-01-23

### Changed

- [共通処理をcrawlineに切り出して、crawlineベースで再実装する](https://redmine.u6k.me/issues/6735)
    - `scoring-horse-racing`プロジェクトからクローリング処理を移動して、整理しました
    - 以前のバージョンとの互換性は失われています

## [0.1.0] - 2018-10-03

### Added

- [スクレイピングのルールを定義できます](https://redmine.u6k.me/issues/6561)

## [0.0.1] - 2018-09-27

### Added

- [空のアプリケーションとして起動します](https://redmine.u6k.me/issues/6559)
  - ヘルスチェックを返します
