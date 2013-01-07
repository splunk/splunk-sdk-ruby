module Synonyms # :nodoc:
  # Make method _new_name_ a synonym for method _old_name_ on this class.
  #
  # _new_name_ and _old_name_ should be strings.
  #
  def synonym(new_name, old_name)
    define_method(new_name) do |*args, &block|
      old_method = old_name.intern
      send(old_method, *args, &block)
    end
  end
end

