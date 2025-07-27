import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:safelink/constants/app_colors.dart';
import 'package:lottie/lottie.dart'; // Add this to your pubspec.yaml

// class GeminiChatPage extends StatefulWidget {
//   const GeminiChatPage({super.key});
//
//   @override
//   State<GeminiChatPage> createState() => _GeminiChatPageState();
// }

class GeminiChatPage extends StatefulWidget {
  final String? urlStatus; // 'benign', 'malicious', etc.
  final String? url; // The actual URL that was scanned

  const GeminiChatPage({super.key, this.urlStatus, this.url});

  @override
  State<GeminiChatPage> createState() => _GeminiChatPageState();
}

class _GeminiChatPageState extends State<GeminiChatPage> {
  final Gemini _gemini = Gemini.instance;
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _hasShownInitialExplanation = false;

  @override
  void initState() {
    super.initState();
    if (widget.urlStatus != null && !_hasShownInitialExplanation) {
      _showInitialExplanation();
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _messages.clear();
      _hasShownInitialExplanation = false;
      //_isLoading = false;
    });

    // Optional: re-show initial explanation
    if (widget.urlStatus != null) {
      await Future.delayed(const Duration(milliseconds: 500)); // give it a small delay
      _showInitialExplanation();
    }
  }

  void _showInitialExplanation() async {
    final status = widget.urlStatus!;
    final url = widget.url ?? 'the URL';

    setState(() {
      _hasShownInitialExplanation = true;
      _isLoading = true;

      // Add temporary loading bubble
      _messages.add(ChatMessage(
        text: 'typing...', // You can use placeholder text
        isUser: false,
        isSystem: true,
      ));
    });

    String prompt;
    if (status == 'benign') {
      prompt = "Explain what benign URL. Give tips on browsing websites. Keep it concise (under 100 words).";
    } else if (status == 'phishing') {
      prompt = "Explain what phishing URL and why $url is phishing. Give tips on why it's not recommended to browse phishing websites. Keep it concise (under 100 words).";
    } else if (status == 'malware') {
      prompt = "Explain what malware URL and why $url is malware. Give tips on why it's not recommended to browse malware websites. Keep it concise (under 100 words).";
    } else {
      prompt = "Explain why $url might be considered potentially dangerous in simple terms. Include potential red flags and security risks. Keep it concise (under 100 words).";
    }

    try {
      final response = await _gemini.text(prompt);
      setState(() {
        _isLoading = false;

        // Replace the last message (the "typing" one) with real content
        _messages.removeLast();
        _messages.add(ChatMessage(
          text: response?.output ?? "No response",
          isUser: false,
          isSystem: true,
        ));
      });
    } catch (e) {
      setState(() {
        _isLoading = false;

        // Remove the typing bubble and show error message
        _messages.removeLast();
        _messages.add(ChatMessage(
          text: "⚠️ Failed to get safety explanation. Please try again later.",
          isUser: false,
          isSystem: true,
        ));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to connect to chatbot. Please check your connection or try again later.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }



  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    // Check if message is URL-related
    if (!_isUrlRelated(message)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please only ask questions about website safety and URLs'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _messages.add(ChatMessage(text: message, isUser: true));
      _isLoading = true;
      _controller.clear();
    });

    // Add context to keep responses focused
    final prompt = "Regarding website safety and URLs: $message. "
        "Please provide a concise answer focused only on URL safety analysis, "
        "website trustworthiness indicators, and cybersecurity best practices. "
        "If the question is not about URLs or internet browsing security, politely decline to answer.";

    // _gemini.text(prompt).then((response) {
    //   setState(() {
    //     _isLoading = false;
    //     if (response != null) {
    //       _messages.add(ChatMessage(
    //         text: response.output ?? "No response",
    //         isUser: false,
    //       ));
    //     }
    //   });
    // });

    try {
      final response = await _gemini.text(prompt);
      setState(() {
        _isLoading = false;
        if (response != null) {
          _messages.add(ChatMessage(
            text: response.output ?? "No response",
            isUser: false,
          ));
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _messages.add(ChatMessage(
          text: "⚠️ Chatbot connection failed. Please try again later.",
          isUser: false,
        ));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to connect to Gemini chatbot.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 3),
        ),
      );
    }

  }

  bool _isUrlRelated(String message) {
    final keywords = [
      'url', 'website', 'link', 'safe', 'dangerous',
      'malicious', 'phishing', 'trust', 'security',
      'http', 'https', 'domain', 'scam', 'fraud'
    ];

    final lowerMessage = message.toLowerCase();
    return keywords.any((word) => lowerMessage.contains(word));
  }



  // void _sendMessage() {
  //   final message = _controller.text.trim();
  //   if (message.isEmpty) return;
  //
  //   setState(() {
  //     _messages.add(ChatMessage(text: message, isUser: true));
  //     _isLoading = true;
  //     _controller.clear();
  //   });
  //
  //   _gemini.text(message).then((response) {
  //     setState(() {
  //       _isLoading = false;
  //       if (response != null) {
  //         _messages.add(ChatMessage(text: response.output ?? "No response", isUser: false));
  //       } else {
  //         _messages.add(ChatMessage(text: "Failed to get response", isUser: false));
  //       }
  //     });
  //   }).catchError((error) {
  //     setState(() {
  //       _isLoading = false;
  //       _messages.add(ChatMessage(text: "Error: $error", isUser: false));
  //     });
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini Chat Assistant'),
        backgroundColor: AppColors.primaryBlue,//Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: _messages.isEmpty
                  ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset(
                          'assets/lottie/Anima Bot.json',
                          width: 200,
                          height: 200,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'How can I help you today?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _messages.length) {
                    return _ChatBubble(message: _messages[index]);
                  } else {
                    return const _TypingBubble();
                  }
                },
              ),
            ),
          ),

          // Expanded(
          //   child: RefreshIndicator(
          //     onRefresh: _handleRefresh,
          //     child: _messages.isEmpty
          //         ? ListView(
          //       physics: const AlwaysScrollableScrollPhysics(),
          //       children: [
          //         const SizedBox(height: 100),
          //         Center(
          //           child: Column(
          //             mainAxisAlignment: MainAxisAlignment.center,
          //             children: [
          //               Lottie.asset(
          //                 'assets/lottie/Anima Bot.json',
          //                 width: 200,
          //                 height: 200,
          //               ),
          //               const SizedBox(height: 20),
          //               const Text(
          //                 'How can I help you today?',
          //                 style: TextStyle(
          //                   color: Colors.white,
          //                   fontWeight: FontWeight.bold,
          //                 ),
          //               ),
          //             ],
          //           ),
          //         ),
          //       ],
          //     )
          //         : ListView.builder(
          //       padding: const EdgeInsets.all(8),
          //       itemCount: _messages.length + (_isLoading ? 1 : 0),
          //       itemBuilder: (context, index) {
          //         if (index < _messages.length) {
          //           return _ChatBubble(message: _messages[index]);
          //         } else {
          //           return const _TypingBubble();
          //         }
          //       },
          //     ),
          //   ),
          // ),

          // Expanded(
          //   child: _messages.isEmpty
          //       ? Center(
          //     child: Column(
          //       mainAxisAlignment: MainAxisAlignment.center,
          //       children: [
          //         Lottie.asset(
          //           'assets/lottie/Anima Bot.json', // Add your own Lottie animation
          //           width: 200,
          //           height: 200,
          //         ),
          //         const SizedBox(height: 20),
          //         Text(
          //           'How can I help you today?',
          //           style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)//Theme.of(context).textTheme.titleMedium,
          //
          //         ),
          //       ],
          //     ),
          //   )
          //       : ListView.builder(
          //     padding: const EdgeInsets.all(8),
          //     itemCount: _messages.length + (_isLoading ? 1 : 0),
          //     itemBuilder: (context, index) {
          //       if (index < _messages.length) {
          //         return _ChatBubble(message: _messages[index]);
          //       } else {
          //         // return const Padding(
          //         //   padding: EdgeInsets.all(16.0),
          //         //   child: Center(child: CircularProgressIndicator()),
          //         // );
          //         return const _TypingBubble();
          //       }
          //     },
          //   ),
          // ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  shape: const CircleBorder(),
                  color: AppColors.primaryBlue,//Theme.of(context).colorScheme.primary,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _sendMessage,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )

        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isSystem;

  ChatMessage({required this.text, required this.isUser, this.isSystem = false,});
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isSystem
              ? Colors.blue[50]
              : message.isUser
              ? AppColors.primaryBlue//Theme.of(context).colorScheme.primary
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: message.isSystem
              ? Border.all(color: Colors.blue)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isSystem)
              const Text(
                'Safety Explanation',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(),
            const SizedBox(width: 4),
            _Dot(delay: Duration(milliseconds: 200)),
            const SizedBox(width: 4),
            _Dot(delay: Duration(milliseconds: 400)),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final Duration delay;
  const _Dot({this.delay = Duration.zero});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 800),
    vsync: this,
  )..repeat(reverse: true);

  late final Animation<double> _animation = Tween(begin: 0.3, end: 1.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: const Text(
        '.',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      ),
    );
  }
}
