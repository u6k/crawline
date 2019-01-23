# crawline

[![Travis](https://img.shields.io/travis/u6k/crawline.svg)](https://travis-ci.org/u6k/crawline)
[![license](https://img.shields.io/github/license/u6k/crawline.svg)](https://github.com/u6k/crawline/blob/master/LICENSE)
[![GitHub release](https://img.shields.io/github/release/u6k/crawline.svg)](https://github.com/u6k/crawline/releases)
[![Website](https://img.shields.io/website-up-down-green-red/https/redmine.u6k.me%2Fprojects%2Fcrawline.svg?label=u6k.Redmine)](https://redmine.u6k.me/projects/crawline)
[![standard-readme compliant](https://img.shields.io/badge/readme%20style-standard-brightgreen.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)

> クローラー向けのクラス・ライブラリ

クローラー向けにクローリング・エンジン、キャッシュ管理、スクレイピング・ルールのベース・クラスを提供します。クローラーは、スクレイピング・ルールをクラスとして実装して、クローリング・エンジンに登録することで、簡単にクローリングを行うことができます。

__Table of Contents__

__TODO:__ Table of Contents

## Background

クローラーのライブラリやフレームワークはいくつもありますが、これらは私がほしい要件を満たしませんでした。私は次の要件を満たしたく、そのために当ライブラリを実装しました。

- Webページのダウンロード可否を複雑なルールで制御したい
  - 前回のダウンロードが1日前以上で、ページ内のデータが1年以内の場合、など
- ダウンロードしたデータはS3ストレージに格納したい
  - 既存のクローラーは、ほとんどの場合、ローカル・ストレージに格納する機能を持っています
- Webページを解析して次にダウンロードするURLを構築したい
  - 単純にWebページのaタグを辿るのではなく

クローリングをどのように実行するのか(CLIアプリケーション、Webアプリケーション、など…)は、当ライブラリを実装する側の責務とします。

## Install

```
gem 'crawline', :git => 'git://github.com/u6k/crawline.git'
```

## Usage

### S3をセットアップする

ダウンロードしたWebデータは、S3互換ストレージに格納します。あらかじめ、Amazon S3のバケットを作成して、アクセス・キーなど必要情報を入手してください。

ローカル環境のみで実行したい場合、S3互換ストレージとして[minio](https://www.minio.io/)などを利用することができます。実際、当プロジェクトもテスト実行の場合は`minio`を利用しています。詳細は、[docker-compose.yml](https://github.com/u6k/crawline/blob/master/docker-compose.yml)を参照してください。

### スクレイピング・ルールを作成する

スクレイピング・ルールの作成は、次のspecを参照してください。

__TODO:__ ルール実装例を記述する

### クローリングを開始する

クローリングを開始するには、次のように実装してください。

__TODO:__ クローリング開始の実装例を記述する

## Reference

### コンポーネント構造

__TODO:__ コンポーネント構造を説明する

### API

__TODO:__ APIドキュメントへのリンクを示す

## Maintainer

- u6k
  - [Twitter](https://twitter.com/u6k_yu1)
  - [GitHub](https://github.com/u6k)
  - [Blog](https://blog.u6k.me/)

## Contribute

当プロジェクトに興味を持っていただき、ありがとうございます。[新しいチケットを起票](https://redmine.u6k.me/projects/crawline/issues/new)していただくか、プルリクエストをサブミットしていただけると幸いです。

当プロジェクトは、[Contributor Covenant](https://www.contributor-covenant.org/version/1/4/code-of-conduct)に準拠します。

## License

[MIT License](https://github.com/u6k/crawline/blob/master/LICENSE)
