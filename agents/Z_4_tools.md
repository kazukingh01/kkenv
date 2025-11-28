# 便利ツール

## HTML画像確認

- `pyplaywright` は任意のウィンドウサイズでブラウザに表示されたHTMLを、操作し、スクリーンショットでpng保存できるツールである
- `pyplaywright --help` で使い方を確認して. JSONコマンド例もそこにある
- このコマンドは `alias` で登録されている. もしあなたがこのコマンドを使えない場合、詳細を `cat ~/.bashrc | grep pyplaywright` で確認して.

```bash
pyplaywright -f ./mock/XXXXXX.html -a 'json形式HTML操作コマンド'
```

