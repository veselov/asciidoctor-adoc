require 'minitest/autorun'
require 'asciidoctor'
require 'asciidoctor-asciidoc'

# credit: https://github.com/owenh000/asciidoctor-multipage/blob/master/test/test_asciidoctor-multipage.rb

class AsciidoctorAsciiDocTest < Minitest::Test
  def test_conversions
    dir = 'test/conversions'
    update_files = ENV["ADC_UPDATE_FILES"].to_i
    run_only = ENV["ADC_RUN_ONLY"]
    has_run = false
    Dir.foreach(dir) do |filename|
      next if filename == '.' or filename == '..'
      doc_path = File.join(dir, filename)
      next unless File.directory?(doc_path)
      next unless run_only != nil && run_only == filename
      has_run = true
      adoc_path = File.join(doc_path, 'input.adoc')
      Asciidoctor.convert_file(adoc_path,
                                     :to_dir => 'test/out',
                                     :to_file => true,
                                     :mkdirs => true,
                                     :header_footer => false,
                                     :backend => 'asciidoc')
      page_path_before = File.join(doc_path, 'converted.adoc')
      page_path_after = 'test/out/input.adoc'
      File.open(page_path_after) do |fa|
        if update_files > 0
          File.open(page_path_before, 'w') do |fb|
            fb.write(fa.read)
          end
        else
          File.open(page_path_before) do |fb|
            assert_equal fb.read, fa.read
          end
        end
      end
    end

    assert run_only.nil? || has_run, "Specified test #{run_only} not found"

  end
end
