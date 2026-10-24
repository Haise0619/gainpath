import 'package:test/test.dart';
import 'package:gainpath_domain/chatbot.dart';
class Chat extends ChatRepository {
 @override List<ChatMessage> get chatSeed=>[];
 @override final List<String> savedAdvice=[];
 @override List<FaqPrompt> get faqPrompts=>[];
 @override String buildProgressAuditReply()=>'';
}
void main(){test('chat acknowledgement and bookmarks use asynchronous shared repository contract',()async{
 dynamic repo=Chat();dynamic initial=await repo.initialize();expect(initial.acknowledged,false);
 await repo.acknowledgeDisclaimer(initial.disclaimer);expect((await repo.initialize()).acknowledged,true);
 await repo.setBookmarked('Advice',true);await repo.setBookmarked('Advice',true);expect(repo.savedAdvice,['Advice']);
 await repo.setBookmarked('Advice',false);expect(repo.savedAdvice,isEmpty);
});}
