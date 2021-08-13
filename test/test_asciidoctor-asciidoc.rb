require 'minitest/autorun'
require 'asciidoctor'
require 'asciidoctor-asciidoc'
require 'tmpdir'

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
      next unless run_only == nil || run_only == filename
      printf(%(Testing #{filename}\n))
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

      # convert both documents to HTML, and see if they're equal
      # supposedly, we don't need this if our converted .adoc are "correct"
      # but this helps catch problems quicker
      [[adoc_path, '1'], [page_path_after, '2']].each do |pi|
        Asciidoctor.convert_file(pi[0],
                                 :to_dir => %(test/out#{pi[1]}),
                                 :to_file => true,
                                 :mkdirs => true,
                                 :header_footer => false,
                                 :backend => 'html5')
      end

      page_path_before = 'test/out1/input.html'
      page_path_after = 'test/out2/input.html'
      File.open(page_path_after) do |fa|
        File.open(page_path_before) do |fb|
          assert_equal fb.read, fa.read
        end
      end

    end

    assert has_run, "Specified test #{run_only} not found"

  end
end
