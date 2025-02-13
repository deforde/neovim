-- Insert-mode tests.

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local expect = helpers.expect
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local meths = helpers.meths
local poke_eventloop = helpers.poke_eventloop

describe('insert-mode', function()
  before_each(function()
    clear()
  end)

  it('CTRL-@', function()
    -- Inserts last-inserted text, leaves insert-mode.
    insert('hello')
    feed('i<C-@>x')
    expect('hellhello')

    -- C-Space is the same as C-@.
    -- CTRL-SPC inserts last-inserted text, leaves insert-mode.
    feed('i<C-Space>x')
    expect('hellhellhello')

    -- CTRL-A inserts last inserted text
    feed('i<C-A>x')
    expect('hellhellhellhelloxo')
  end)

  describe('Ctrl-R', function()
    it('works', function()
      command("let @@ = 'test'")
      feed('i<C-r>"')
      expect('test')
    end)

    it('works with multi-byte text', function()
      command("let @@ = 'påskägg'")
      feed('i<C-r>"')
      expect('påskägg')
    end)
  end)

  describe('Ctrl-O', function()
    it('enters command mode for one command', function()
      feed('ihello world<C-o>')
      feed(':let ctrlo = "test"<CR>')
      feed('iii')
      expect('hello worldiii')
      eq(1, eval('ctrlo ==# "test"'))
    end)

    it('re-enters insert mode at the end of the line when running startinsert', function()
      -- #6962
      feed('ihello world<C-o>')
      feed(':startinsert<CR>')
      feed('iii')
      expect('hello worldiii')
    end)

    it('re-enters insert mode at the beginning of the line when running startinsert', function()
      insert('hello world')
      feed('0<C-o>')
      feed(':startinsert<CR>')
      feed('aaa')
      expect('aaahello world')
    end)

    it('re-enters insert mode in the middle of the line when running startinsert', function()
      insert('hello world')
      feed('bi<C-o>')
      feed(':startinsert<CR>')
      feed('ooo')
      expect('hello oooworld')
    end)
  end)

  describe('Ctrl-V', function()
    it('supports entering the decimal value of a character', function()
      feed('i<C-V>076<C-V>167')
      expect('L§')
    end)

    it('supports entering the octal value of a character with "o"', function()
      feed('i<C-V>o114<C-V>o247<Esc>')
      expect('L§')
    end)

    it('supports entering the octal value of a character with "O"', function()
      feed('i<C-V>O114<C-V>O247<Esc>')
      expect('L§')
    end)

    it('supports entering the hexadecimal value of a character with "x"', function()
      feed('i<C-V>x4c<C-V>xA7<Esc>')
      expect('L§')
    end)

    it('supports entering the hexadecimal value of a character with "X"', function()
      feed('i<C-V>X4c<C-V>XA7<Esc>')
      expect('L§')
    end)

    it('supports entering the hexadecimal value of a character with "u"', function()
      feed('i<C-V>u25ba<C-V>u25C7<Esc>')
      expect('►◇')
    end)

    it('supports entering the hexadecimal value of a character with "U"', function()
      feed('i<C-V>U0001f600<C-V>U0001F601<Esc>')
      expect('😀😁')
    end)

    it('entering character by value is interrupted by invalid character', function()
      feed('i<C-V>76c<C-V>76<C-F2><C-V>u3c0j<C-V>u3c0<M-F3><C-V>U1f600j<C-V>U1f600<D-F4><Esc>')
      expect('LcL<C-F2>πjπ<M-F3>😀j😀<D-F4>')
    end)

    it('shows o, O, u, U, x, X, and digits with modifiers', function()
      feed('i<C-V><M-o><C-V><D-o><C-V><M-O><C-V><D-O><Esc>')
      expect('<M-o><D-o><M-O><D-O>')
      feed('cc<C-V><M-u><C-V><D-u><C-V><M-U><C-V><D-U><Esc>')
      expect('<M-u><D-u><M-U><D-U>')
      feed('cc<C-V><M-x><C-V><D-x><C-V><M-X><C-V><D-X><Esc>')
      expect('<M-x><D-x><M-X><D-X>')
      feed('cc<C-V><M-1><C-V><D-2><C-V><M-7><C-V><D-8><Esc>')
      expect('<M-1><D-2><M-7><D-8>')
    end)
  end)

  it('Ctrl-Shift-V supports entering unsimplified key notations', function()
    feed('i<C-S-V><C-J><C-S-V><C-@><C-S-V><C-[><C-S-V><C-S-M><C-S-V><M-C-I><C-S-V><C-D-J><Esc>')
    expect('<C-J><C-@><C-[><C-S-M><M-C-I><C-D-J>')
  end)

  describe([[With 'insertmode', Insert mode is not re-entered immediately after <C-L>]], function()
    before_each(function()
      command('set insertmode')
      poke_eventloop()
      eq({mode = 'i', blocking = false}, meths.get_mode())
    end)

    it('after calling :edit from <Cmd> mapping', function()
      command('inoremap <C-B> <Cmd>edit Xfoo<CR>')
      feed('<C-B><C-L>')
      poke_eventloop()
      eq({mode = 'n', blocking = false}, meths.get_mode())
    end)

    it('after calling :edit from RPC #16823', function()
      command('edit Xfoo')
      feed('<C-L>')
      poke_eventloop()
      eq({mode = 'n', blocking = false}, meths.get_mode())
    end)
  end)
end)
