class IndividualNoteDiscussion < Discussion
  # Keep this method in sync with the `potentially_resolvable` scope on `ResolvableNote`
  def potentially_resolvable?
    false
  end

  def individual_note?
    true
  end
end
