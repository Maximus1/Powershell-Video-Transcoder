Describe 'Video Transcoder Tests' {
    It 'should return the correct output for a given input' {
        $input = 'input.mp4'
        $expectedOutput = 'output.mp4'
        $actualOutput = Invoke-VideoTranscoder -InputFile $input
        $actualOutput | Should -BeExactly $expectedOutput
    }
}