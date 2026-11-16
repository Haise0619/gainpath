import 'package:gainpath_pose/gainpath_pose.dart';

class ReplayPoseDetector implements ManagedPoseDetector {
  late PoseFrame frame;
  @override
  Future<PoseFrame> detect(PoseInput input) async => frame;
  @override
  Future<void> reset() async {}
  @override
  Future<void> close() async {}
}
