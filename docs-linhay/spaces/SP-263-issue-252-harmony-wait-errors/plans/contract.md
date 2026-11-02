# Harmony wait typed errors

影响层：CLI host wait 错误输出与机器可读恢复，不改设备、shared SDK、Web、运行时wait轮询或#147暂态recv重试。

## BDD

- Given fake HDC列表中没有显式target，When wait以--target或--device执行，Then单JSON、exit1、target_not_found，与observe tree原因一致；无虚假的/request endpoint，nextAction只列Harmony targets并保留--hdc。
- Given显式不存在HDC路径或不存在PATH命令，Then harmony_hdc_not_found、明确--hdc配置hint和绑定该配置的检查nextAction，不宣称server不可用。
- Given HDC启动后非零退出，Then保留host错误；真实runtime连接失败仍server_unavailable及真实endpoint/recovery。
- Given --idle，Then unsupported_capability且HDC调用数为零。
- Given正常条件未命中，Then维持wait结果timedOut=true；#147 dump/recv暂态重试、gone不误判保留已有测试。

先写HarmonyWaitFailureTests与现有binary fake-HDC RED；Swift测试等待主控串行构建槽。新helper限定hostHarmony分支，不自动切换target、启动服务或重放动作。错误信息不是原wait条件通过证据。

## 已确认前态与候选

2026-11-02，以实际安装版v0.2.38运行受控fake HDC：wait --target、--device缺失目标及显式不存在--hdc路径均输出request_failed并附伪`http://127.0.0.1:19421/request`；同backend的observe tree输出target_not_found且无endpoint。证据`.triton/sp263-validation/baseline-red.json`。这是已发布binary的真实前态RED；新的Swift tests尚未在旧源码执行，不能称为旧源码单测红绿。

最小候选增加`CLIHarmonyWaitFailureRuntime.swift`，只接Wait catch。已知Harmony target错误和missing executable映射有针对性的nextAction，其它host错误复用failHostCommand；CLIHTTPError/URLError/runtime timeout保留runtime路径，ExitCode直接透传防双JSON。launchFailed只有显式配置路径不存在才映射harmony_hdc_not_found；PATH命令需env host查找错误与127同时成立，远端uitest的127不当成缺HDC。

schema仅更新`CLISchemaObservationCommands.swift`中name=wait的failureCodes，加入该路径实际可能返回的host taxonomy；不改轮询、target选择或#147暂态timeout机制。10项新测试加已有HarmonyWaitRuntimeTests等待主控Swift槽；当前仅git diff --check通过。
