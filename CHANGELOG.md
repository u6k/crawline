# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- [#7048: キャッシュ、関連リンクなどをストレージ取得しなくてもDB検索できるようにする](https://redmine.u6k.me/issues/7048)
    - `list_cache_state`を削除しました
    - crawlineが持つDBマイグレーションを適用する必要があります

## [0.17.0] - 2019-05-01

### Removed

- [#7029: バリデーションを削除する](https://redmine.u6k.me/issues/7029)
- [#6982: パース処理の進捗を表示する](https://redmine.u6k.me/issues/6982)

## [0.16.0] - 2019-04-25

### Changed

- [#6998: クローリングと同時にパースも行う](https://redmine.u6k.me/issues/6998)
- [#6996: 再ダウンロードしない場合、パースやバリデーションも行わない](https://redmine.u6k.me/issues/6996)

## [0.15.0] - 2019-04-25

### Changed

- [#7013: データ保存形式を、JSON+BASE64+zipにする](https://redmine.u6k.me/issues/7013)

## [0.14.0] - 2019-04-09

### Changed

- [#6890: キャッシュ状態検索を、結果を返すのではなくブロックを処理するように変更する](https://redmine.u6k.me/issues/6890)

## [0.13.0] - 2019-04-02

### Added

- [#6888: リンクに対してキャッシュが存在するか確認したい](https://redmine.u6k.me/issues/6888)

## [0.12.0] - 2019-04-01

### Added

- [#6878: ダウンロードかスキップかをログ出力する](https://redmine.u6k.me/issues/6878)

## [0.11.0] - 2019-03-29

### Changed

- [#6871: エンジンがパースするときにデータがない場合はスキップする](https://redmine.u6k.me/issues/6871)

## [0.10.0] - 2019-03-27

### Changed

- [#6863: 格納データのマーシャリングやzip圧縮は、エンジンではなくリポジトリで行う](https://redmine.u6k.me/issues/6863)

## [0.9.0] - 2019-03-27

### Added

- [#6819: キャッシュ済みページを検索、削除したい](https://redmine.u6k.me/issues/6819)

## [0.8.1] - 2019-03-22

### Fixed

- [#6855: downloaded_timestampが文字列として復元されてしまう](https://redmine.u6k.me/issues/6855)

## [0.8.0] - 2019-03-20

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
