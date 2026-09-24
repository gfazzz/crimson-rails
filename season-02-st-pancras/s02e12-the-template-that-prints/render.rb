#!/usr/bin/env ruby
# frozen_string_literal: true

# CRIMSON RAILS — s02e12. Печатает полосу по шаблону и листу выпуска.
#
#   ruby render.rb <шаблон.erb> <лист.json> <куда.html>
#
# Ничего сверх стандартной библиотеки: ERB и JSON входят в Ruby.
# Этот файл менять не нужно — он здесь целиком, чтобы было видно, что
# происходит между шаблоном и полосой. Шаблон получает лист выпуска в
# переменной issue и печатает из него полосу.

require "erb"
require "json"
require "cgi"

# Экранирование. В обычном ERB <%= %> печатает как есть — значит амперсанд,
# угловая скобка или кавычка из данных попадут в разметку как разметка.
# В Rails то же самое делается само: там <%= %> экранирует всегда.
def h(value)
  CGI.escapeHTML(value.to_s)
end

template, data_file, out = ARGV
abort "нужно: ruby render.rb <шаблон.erb> <лист.json> <куда.html>" unless out

# Кодировка — явно: в терминале с LANG=C Ruby прочтёт файл как ASCII и
# споткнётся на первой кириллической букве.
issue = JSON.parse(File.read(data_file, encoding: "UTF-8"))
erb = ERB.new(File.read(template, encoding: "UTF-8"), trim_mode: "-")
erb.filename = template

File.write(out, erb.result_with_hash(issue: issue), encoding: "UTF-8")
