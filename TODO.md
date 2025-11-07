# SIGINTのハンドル

SIGINTを受けて、統計情報、部首/交ぜ書きの学習データをディスクに同期する。
将来的にはSIGTERMも同様に処理したいが、まずはSIGINTについてのみ実装する。

## 実装方針

- シグナルハンドラ内でのファイルI/Oは困難なため、シグナル検出を伝えるためにpipeを利用する
    - SIGINTのシグナルハンドラではpipeに1バイトを書き込む
    - 別スレッドでpipeを見張っておき、書き込みを検出したら情報同期ルーチンを呼ぶ
    - pipeのファイルハンドルは大域変数で保持してよい
- signalハンドラ、signal見張りスレッド、pipeはAppDelegete内に持つのがよさそうだが、より適切なクラスがあれば提案してほしい

## サンプルコード

以下のサンプルコードを参考にしてよい。そのまま使うのではなく、適宜修正してよい

```
// ---- self-pipe ----
var sigpipe: [Int32] = [0, 0]
guard pipe(&sigpipe) == 0 else { perror("pipe"); _exit(1) }
let sigpipeR = sigpipe[0]
let sigpipeW = sigpipe[1]

// ハンドラから参照するためのグローバル（書き込みFD）
var gSigpipeW: Int32 = sigpipeW

// C呼び出し規約のハンドラ（クロージャ不可）
@_cdecl("sigint_handler")
func sigint_handler(_ signo: Int32, _ info: UnsafeMutablePointer<__siginfo>?, _ uctx: UnsafeMutableRawPointer?) -> Void {
    // async-signal-safe な write() だけを使う
    var one: UInt8 = 1
    // 失敗しても構わない（他にやれることがない）
    _ = withUnsafePointer(to: &one) { ptr in
        ptr.withMemoryRebound(to: UInt8.self, capacity: 1) { p in
            write(gSigpipeW, p, 1)
        }
    }
}

// SIGINT を sigaction で捕捉
var sa = sigaction()
sigemptyset(&sa.sa_mask)
sa.sa_flags = SA_SIGINFO
sa.__sigaction_u.__sa_sigaction = sigint_handler
guard sigaction(SIGINT, &sa, nil) == 0 else { perror("sigaction"); _exit(1) }

// signal watcher
Thread.detachNewThread {
    var buf: UInt8 = 0
    while true {
        let n = read(sigpipeR, &buf, 1)
        if n <= 0 { if errno == EINTR { continue } else { break } }
        InputStats.shared.writeStatsToFile()
        // SIGTERMの場合はここで _exit(0)
    }
}

```
