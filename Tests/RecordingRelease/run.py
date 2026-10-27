from pathlib import Path
import subprocess,sys,tempfile,os
root=Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).resolve().parents[2]
vm=(root/'Sources/ViewModels/TranslatorViewModel.swift').read_text()
def block(text, marker):
 start=text.index(marker); brace=text.index('{',start); depth=1;i=brace+1
 while depth:
  depth+=(text[i]=='{')-(text[i]=='}');i+=1
 return text[start:i]
methods='\n'.join(block(vm,'    func '+n+'(') for n in ['startRecording','stopRecording','cancelRecording'])
obs=vm[vm.index('        audioRecorder.$isRecording'):vm.index('    func requestMicPermission')].rsplit('    }',1)[0]
audio=(root/'Sources/Services/AudioRecorder.swift').read_text()
start_publish=audio[audio.index('        DispatchQueue.main.async {\n            self.isRecording = true'):audio.index('        return url')]
s='''import Foundation
import AppKit
import Combine
class FakeAudio: ObservableObject {
 @Published var isRecording=false
 var active=false
 var isActive:Bool { active }
 func requestMicPermission(completion: @escaping (Bool)->Void) { completion(true) }
 func startRecording() throws -> URL {
  active=true
'''+start_publish+'''
 return URL(fileURLWithPath:"/tmp/unused-test-audio")
 }
 func stopRecording()->URL? { active=false; DispatchQueue.main.async { self.isRecording=false };return URL(fileURLWithPath:"/tmp/unused-test-audio") }
 func cleanup() {}
}
class API { func warmUp() {} }
enum HUD: Equatable { case hidden,listening,error(String) }
@MainActor class PasteboardManager { static func captureTarget()->NSRunningApplication? { nil } }
@MainActor class VM: ObservableObject {
 @Published var isRecording=false
 var isProcessing=false
 var recordingPasteTarget:NSRunningApplication?
 var recordingGeneration=0
 var recordingURL:URL?
 var recordingStartTime:Date?
 var micGranted=false
 var lastError:String?
 var hudState:HUD = .hidden
 let audioRecorder=FakeAudio()
 let apiClient=API()
 init() {
'''+obs+'''
 }
 func processRecording() { hudState = .hidden }
'''+methods+'''
}
Task { @MainActor in
 let vm=VM()
 vm.startRecording()
 vm.stopRecording() // Release queued while the recorder's published state is still in flight.
 try? await Task.sleep(nanoseconds: 30_000_000)
 if vm.audioRecorder.active || vm.hudState == .listening {
  print("FAIL: key released but recorder remains active and Listening persists")
  exit(1)
 }
 print("PASS: immediate release stops recorder and clears Listening")
 vm.startRecording()
 vm.startRecording() // Duplicate down must not replace an active engine.
 try? await Task.sleep(nanoseconds: 30_000_000)
 vm.stopRecording()
 try? await Task.sleep(nanoseconds: 30_000_000)
 precondition(!vm.audioRecorder.active && vm.hudState != .listening)
 vm.startRecording()
 vm.cancelRecording()
 try? await Task.sleep(nanoseconds: 30_000_000)
 precondition(!vm.audioRecorder.active && vm.hudState == .hidden)
 print("PASS: ordinary release and cancellation stop recording")
 exit(0)
}
dispatchMain()
'''
scratch=tempfile.TemporaryDirectory(prefix='vaani-release-test-')
out=Path(scratch.name)
(out/'main.swift').write_text(s)
r=subprocess.run(['swiftc','-module-cache-path',os.environ.get('CLANG_MODULE_CACHE_PATH',str(out/'cache')),str(out/'main.swift'),'-o',str(out/'check')]);
if r.returncode: sys.exit(r.returncode)
sys.exit(subprocess.run([str(out/'check')]).returncode)
