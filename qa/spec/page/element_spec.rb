describe QA::Page::Element do
  context 'when pattern is an expression' do
    subject { described_class.new(:something, /button 'Sign in'/) }

    it 'matches when there is a match' do
      expect(subject.matches?("button 'Sign in'")).to be true
    end

    it 'does not match if pattern is not present' do
      expect(subject.matches?("button 'Sign out'")).to be false
    end
  end

  context 'when pattern is a string' do
    subject { described_class.new(:something, 'button') }

    it 'matches when there is match' do
      expect(subject.matches?('some button in the view')).to be true
    end

    it 'does not match if pattern is not present' do
      expect(subject.matches?('text_field :name')).to be false
    end
  end

  context 'when pattern is not provided' do
    subject { described_class.new(:some_name) }

    it 'matches when QA specific selector is present' do
      expect(subject.matches?('some qa-some-name selector')).to be true
    end

    it 'does not match if QA selector is not there' do
      expect(subject.matches?('some_name selector')).to be false
    end
  end
end
