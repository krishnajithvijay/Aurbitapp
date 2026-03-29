import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/user_model.dart';
import '../../widgets/common/user_avatar.dart';

enum CallState { ringing, connecting, connected, ended }

class CallScreen extends StatefulWidget {
  final UserModel otherUser;
  final bool isVideo;
  final String chatId;
  final bool isIncoming;
  final String? callId;

  const CallScreen({
    super.key,
    required this.otherUser,
    required this.isVideo,
    required this.chatId,
    this.isIncoming = false,
    this.callId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  final _db = SupabaseService.instance;
  CallState _callState = CallState.ringing;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCameraOff = false;
  bool _isFrontCamera = true;
  Duration _callDuration = Duration.zero;
  Timer? _durationTimer;
  Timer? _ringTimer;
  RealtimeChannel? _signalingChannel;
  late String _callId;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _callId = widget.callId ?? DateTime.now().millisecondsSinceEpoch.toString();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    if (widget.isIncoming) {
      _callState = CallState.ringing;
    } else {
      _initiateCall();
    }
    _setupSignaling();

    // Ring timeout
    _ringTimer = Timer(Duration(seconds: AppConstants.callRingTimeout), () {
      if (_callState == CallState.ringing && mounted) _endCall(reason: 'No answer');
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _ringTimer?.cancel();
    _signalingChannel?.unsubscribe();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _initiateCall() async {
    final myId = AuthService.instance.currentUserId;
    if (myId == null) return;

    await _db.client.from(AppConstants.callSignalsTable).insert({
      'id': _callId,
      'caller_id': myId,
      'callee_id': widget.otherUser.id,
      'chat_id': widget.chatId,
      'type': widget.isVideo ? 'video' : 'voice',
      'status': 'ringing',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  void _setupSignaling() {
    _signalingChannel = _db.client
        .channel('call_$_callId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: AppConstants.callSignalsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _callId,
          ),
          callback: (payload) {
            final status = payload.newRecord['status'] as String?;
            if (!mounted) return;
            if (status == 'accepted') {
              setState(() => _callState = CallState.connected);
              _ringTimer?.cancel();
              _startDurationTimer();
              HapticFeedback.mediumImpact();
            } else if (status == 'rejected' || status == 'ended') {
              _endCall(reason: status == 'rejected' ? 'Call declined' : null);
            }
          },
        )
        .subscribe();
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _acceptCall() async {
    await _db.client
        .from(AppConstants.callSignalsTable)
        .update({'status': 'accepted'}).eq('id', _callId);
    setState(() => _callState = CallState.connected);
    _ringTimer?.cancel();
    _startDurationTimer();
    HapticFeedback.mediumImpact();
  }

  Future<void> _endCall({String? reason}) async {
    _durationTimer?.cancel();
    _ringTimer?.cancel();

    await _db.client
        .from(AppConstants.callSignalsTable)
        .update({'status': 'ended'}).eq('id', _callId);

    if (mounted) {
      if (reason != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(reason), duration: const Duration(seconds: 2)),
        );
      }
      Navigator.pop(context);
    }
  }

  String get _durationString {
    final h = _callDuration.inHours;
    final m = (_callDuration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_callDuration.inSeconds % 60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.oledBlack,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D0D1A), Color(0xFF111130), Color(0xFF0D0D1A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Animated rings
          if (_callState == CallState.ringing)
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: _pulseAnim.value * 1.4,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: _pulseAnim.value * 1.2,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                // Status label
                Text(
                  _callState == CallState.ringing
                      ? (widget.isIncoming ? 'Incoming ${widget.isVideo ? 'Video' : 'Voice'} Call' : 'Calling...')
                      : _callState == CallState.connecting
                          ? 'Connecting...'
                          : _callState == CallState.connected
                              ? 'Connected'
                              : 'Call Ended',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(height: 30),
                // Avatar
                UserAvatar(
                  user: widget.otherUser,
                  displayName: widget.otherUser.displayName,
                  radius: 56,
                  borderColor: AppColors.primary.withOpacity(
                    _callState == CallState.connected ? 0.6 : 0.2,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.otherUser.displayName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  _callState == CallState.connected ? _durationString : '@${widget.otherUser.username}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _callState == CallState.connected
                            ? AppColors.accentGreen
                            : AppColors.textMuted,
                        fontFamily: 'monospace',
                      ),
                ),
                const Spacer(),
                // Controls
                if (widget.isIncoming && _callState == CallState.ringing)
                  _buildIncomingControls()
                else
                  _buildActiveControls(),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ControlButton(
              icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: _isMuted ? 'Unmute' : 'Mute',
              color: _isMuted ? AppColors.error : AppColors.darkElevated,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isMuted = !_isMuted);
              },
            ),
            const SizedBox(width: 20),
            if (widget.isVideo)
              _ControlButton(
                icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                label: _isCameraOff ? 'Camera On' : 'Camera Off',
                color: _isCameraOff ? AppColors.error : AppColors.darkElevated,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isCameraOff = !_isCameraOff);
                },
              ),
            if (!widget.isVideo)
              _ControlButton(
                icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
                color: AppColors.darkElevated,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isSpeakerOn = !_isSpeakerOn);
                },
              ),
            const SizedBox(width: 20),
            _ControlButton(
              icon: Icons.call_end_rounded,
              label: 'End',
              color: AppColors.error,
              size: 64,
              onTap: () {
                HapticFeedback.heavyImpact();
                _endCall();
              },
            ),
          ],
        ),
        if (widget.isVideo) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ControlButton(
                icon: Icons.flip_camera_ios_rounded,
                label: 'Flip',
                color: AppColors.darkElevated,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isFrontCamera = !_isFrontCamera);
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildIncomingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlButton(
          icon: Icons.call_end_rounded,
          label: 'Decline',
          color: AppColors.error,
          size: 64,
          onTap: () {
            HapticFeedback.heavyImpact();
            _endCall(reason: 'Call declined');
          },
        ),
        const SizedBox(width: 60),
        _ControlButton(
          icon: widget.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
          label: 'Accept',
          color: AppColors.accentGreen,
          size: 64,
          onTap: () {
            HapticFeedback.mediumImpact();
            _acceptCall();
          },
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    this.size = 56,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.45),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
