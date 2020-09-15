# Crawline _(crawline)_

[![Build Status](https://travis-ci.org/u6k/crawline.svg?branch=master)](https://travis-ci.org/u6k/crawline) [![license](https://img.shields.io/github/license/u6k/crawline.svg)](LICENSE) [![GitHub release](https://img.shields.io/github/release/u6k/crawline.svg)](https://github.com/u6k/crawline/releases) [![Website](https://img.shields.io/website/https/redmine.u6k.me/projects/crawline.svg?label=u6k.Redmine)](https://redmine.u6k.me/projects/crawline) [![Website](https://img.shields.io/website/https/u6k.github.io/crawline.svg?label=API%20%20document)](https://u6k.github.io/crawline/) [![standard-readme compliant](https://img.shields.io/badge/readme%20style-standard-brightgreen.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)

> __NOTE:__ 本プロジェクトはアーカイブしました。Scrapyを使うことにしたため、本プロジェクトを使わなくなったためです。

> クローラー向けのクラス・ライブラリ

クローラー向けにクローリング・エンジン、キャッシュ管理、パーサーのベース・クラスを提供します。パーサーを実装してクローリング・エンジンに登録することで、簡単にクローリングを行うことができます。

__Table of Contents__

- [Background](#Background)
- [Install](#Install)
- [Usage](#Usage)
    - [S3をセットアップする](#S3をセットアップする)
    - [パーサーを実装する](#パーサーを実装する)
    - [クローリングを開始する](#クローリングを開始する)
- [Other](#Other)
- [API](#API)
- [Maintainer](#Maintainer)
- [Contribute](#Contribute)
- [License](#License)

## Background

クローラーのライブラリやフレームワークはいくつもありますが、これらは私がほしい要件を満たしませんでした。私は次の要件を満たしたく、そのために当ライブラリを実装しました。

- Webページのダウンロード可否を複雑なルールで制御したい
    - 前回のダウンロードが1日前以上で、ページ内のデータが1年以内の場合、など
- ダウンロードしたデータはS3ストレージに格納したい
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

ローカル環境のみで実行したい場合、S3互換ストレージとして [minio](https://www.minio.io/) などを利用することができます。実際、当プロジェクトもテスト実行の場合はminioを利用しています。詳細は、 [docker-compose.yml](docker-compose.yml) を参照してください。

### パーサーを実装する

テスト用に簡単なパーサーを実装してあります。 [spec/test_parser.rb](spec/test_parser.rb) を参照してください。

### クローリングを開始する

クローリングは`Crawline::Engine`が行いますので、これを初期化します。

`Crawline::Engine`は、`Crawline::Downloader`、`Crawline::ResourceRepository`、そしてパーサー配列を必要とします。

```
# User-Agentを渡して、Crawline::Downloaderを初期化する。
downloader = Crawline::Downloader.new("test/0.0.0")

# S3認証情報を渡して、Crawline::ResourceRepositoryを初期化する。
repo = Crawline::ResourceRepository.new(access_key, secret_key, region, bucket, endpoint, force_path_style)

# 正規表現とパーサーの配列を構築する。
# URLが正規表現にマッチしたパーサーを使用して、ダウンロードしたデータをパースする。
parsers = {
  /https:\/\/blog.example.com\/index\.html/ => BlogListTestParser,
  /https:\/\/blog.example.com\/page[0-9]+\.html/ => BlogListTestParser,
  /https:\/\/blog.example.com\/pages\/.*\.html/ => BlogPageTestParser,
}

# Crawline::Engineを初期化する。
engine = Crawline::Engine.new(downloader, repo, parsers)
```

クローリングは、`Crawline::Engine#crawl`メソッドにURLを渡すことで行います。

```
engine.crawl("https://blog.example.com/index.html")
```

クロールは、実際は「Webからデータをダウンロード」しています。パースはこの後に`Crawline::Engine#parse`メソッドにURLを渡すことで行います。

```
result = engine.parse("https://blog.example.com/index.html")
```

パースは、実際は「各パーサーの`parse`メソッドを呼び出し、`context`に設定された値を返す」を行います。

テスト用に簡単なクロール & パースを実装してあります。 [spec/crawline_spec.rb](spec/crawline_spec.rb) を参照してください。

## Other

最新の情報は、 [Wiki - crawline - u6k.Redmine](https://redmine.u6k.me/projects/crawline/wiki) を参照してください。

## API

[APIリファレンス](https://u6k.github.io/crawline/) を参照してください。

## Maintainer

- u6k
    - [Twitter](https://twitter.com/u6k_yu1)
    - [GitHub](https://github.com/u6k)
    - [Blog](https://blog.u6k.me/)

## Contribute

当プロジェクトに興味を持っていただき、ありがとうございます。 [新しいチケットを起票](https://redmine.u6k.me/projects/crawline/issues/) していただくか、プルリクエストをサブミットしていただけると幸いです。

当プロジェクトは、 [Contributor Covenant](https://www.contributor-covenant.org/version/1/4/code-of-conduct) に準拠します。

## License

[MIT License](LICENSE)
