import SwiftUI

struct TalkShowView: View {

    let questionWord: String
    let answerWord: String
    
    @Binding var isPlaying: Bool
    

    let onTogglePlayPause: () -> Void
    let onSkipToPrevious: () -> Void
    let onSkipToNext: () -> Void

   
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text(questionWord)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text(answerWord)
                .font(.title2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()

            HStack(spacing: 40) {
                Button(action: onSkipToPrevious) {
                    Image(systemName: "backward.fill")
                }
                
                Button(action: onTogglePlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 44, height: 44)
                }
                
                Button(action: onSkipToNext) {
                    Image(systemName: "forward.fill")
                }
            }
            .font(.system(size: 44))
            .foregroundColor(.blue)
            .padding(.bottom, 40)
        }
    }
}



#if DEBUG
struct TalkShowView_Previews: PreviewProvider {
    static var previews: some View {

        TalkShowView(
            questionWord: "μπροστά",
            answerWord: "впереди",
            isPlaying: .constant(true),
            onTogglePlayPause: { print("Toggle Play/Pause tapped") },
            onSkipToPrevious: { print("Previous tapped") },
            onSkipToNext: { print("Next tapped") }
        )
    }
}
#endif
