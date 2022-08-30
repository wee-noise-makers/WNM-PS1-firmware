#!/usr/bin/env python3

words = [
    # 99 Most Common Words: US #1 Songs Stat
    'i',
    'you',
    'love',
    'the',
    'me',
    'to',
    'we',
    'be',
    'on',
    'do',
    'go',
    'in',
    'and',
    'no',
    'so',
    'it',
    'is',
    'my',
    'your',
    'can',
    'for',
    'of',
    'are',
    'when',
    'girl',
    'one',
    'what',
    'man',
    'boy',
    'two',
    'like',
    'woman',
    'that',
    'will',
    'dont',
    'all',
    'up',
    'heart',
    'this',
    'baby',
    'with',
    'if',
    'cant',
    'too',
    'how',
    'have',
    'time',
    'want',
    'there',
    'night',
    'get',
    'down',
    'good',
    'out',
    'from',
    'your', # You're
    #'I'm',
    'say',
    'just',
    'life',
    'its', #'It's
    'now',
    'know',
    'live',
    'got',
    'way',
    'take',
    'song',
    'give',
    'come',
    'bad',
    'make',
    'more',
    'over',
    'world',
    'kiss',
    'back',
    'black',
    #'I'll',
    'eyes',
    'without',
    'stop',
    'together',
    'away',
    'little',
    'rock',
    'about',
    'hold',
    'girls',
    'again',
    'tonight',
    'lady',
    'hey',
    'loves',
    'lets',
    'fire',
    'gonna',
    'everything',
    'keep',
    #'mister',
    'angel',
    'shake',
    'theme',

    'abstract',
    'accident',
    'acid',
    'acquired',
    'action',
    'activated',
    'advanced',
    'aerial',
    'again',
    'against',
    'alive',
    'allowed',
    'alone',
    'alpha',
    'altered',
    'amazing',
    'analyze',
    'angry',
    'animal',
    'answer',
    'anxiety',
    'any',
    'anymore',
    'arcade',
    'are',
    'arrest',
    'artificial',
    'attack',
    'based',
    'basic',
    'bass',
    'battery',
    'beat',
    'beautiful',
    'beta',
    'better',
    'bike',
    'billion',
    'binary',
    'bird',
    'bite',
    'blame',
    'block',
    'blue',
    'bodies',
    'body',
    'bored',
    'boss',
    'box',
    'brain',
    'brain',
    'brakes',
    'break',
    'broadcast',
    'broke',
    'broken',
    'brother',
    'brutal',
    'bubble',
    'buddy',
    'bugs',
    'bullet',
    'burn',
    'bye',
    'cable',
    'cake',
    'called',
    'calls',
    'cancelled',
    'candy',
    'carbon',
    'cash',
    'catch',
    'celebrate',
    'celebration',
    'centuries',
    'champion',
    'chaos',
    'cheap',
    'check',
    'checked',
    'citizen',
    'clear',
    'click',
    'clone',
    'club',
    'combat',
    'computer',
    'connect',
    'console',
    'continue',
    'control',
    'cool',
    'crash',
    'crew',
    'damage',
    'danger',
    'darkness',
    'data',
    'day',
    'defects',
    'delete',
    'denied',
    'device',
    'dirt',
    'done',
    'dont',
    'doubt',
    'download',
    'dragon',
    'free',
    'gadgets',
    'green',
    'human',
    'hands',
    'it',
    'maker',
    'music',
    'noise',
    'point',
    'robot',
    'roll',
    'shake',
    'sister',
    'television',
    'tell',
    'tension',
    'terminal',
    'terror',
    'test',
    'the',
    'theory',
    'throw',
    'thumbs',
    'ticket',
    'tiger',
    'times',
    'tissue',
    'today',
    'together',
    'tomorrow',
    'tonight',
    'touch',
    'toxic',
    'track',
    'trash',
    'turbo',
    'turn',
    'twist',
    'undefined',
    'unique',
    'united',
    'update',
    'upload',
    'ur',
    'urban',
    'vice',
    'victory',
    'vintage',
    'virtual',
    'voice',
    'volume',
    'wait',
    'waiting',
    'wake',
    'wanna',
    'want',
    'wanted',
    'warning',
    'watch',
    'wave',
    'we',
    'week',
    'weekend',
    'weird',
    'welcome',
    'when',
    'wicked',
    'will',
    'wind',
    'winner',
    'wish',
    'without',
    'yeah',
    'year',
    'yes',
    'your',
    'zone',
    
    'black',
    'white',
    'green',
    'blue',
    'red',
    'yellow',
    
    'first',
    'last',
    'zero',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
]


def is_ada_keyword(word):
    return word in ["abort", "else", "new", "return", "abs", "elsif", "not", 
                    "reverse", "abstract", "end", "null", "accept", "entry",
                    "select", "access", "exception", "of", "separate",
                    "aliased", "exit", "or", "some", "all", "others",
                    "subtype", "and", "for", "out", "synchronized", "array",
                    "function", "overriding", "at", "tagged", "generic",
                    "package", "task", "begin", "goto", "pragma", "terminate",
                    "body", "private", "then", "if", "procedure", "type",
                    "case", "in", "protected", "constant", "interface",
                    "until", "is", "raise", "use", "declare", "range",
                    "delay", "limited", "record", "when", "delta", "loop",
                    "rem", "while", "digits", "renames", "with", "do", "mod",
                    "requeue", "xor"]

words = sorted(set(words))

last_word = words[-1]
packages = set()

for word in words:
    prefix = word[0:2] if len(word) >= 2 else word+word
    if is_ada_keyword(prefix):
        packages.add(prefix.upper() + "_K")
    else:
        packages.add(prefix.upper())

print("with LPC_Synth;")
print("with WNM.Speech;")

for p in packages:
    print(f"with LPC_Synth.Vocab_Festival.{p.upper()};")

print("")
print("package WNM.Speech_Dictionary is")
print("   package Vocab renames LPC_Synth.Vocab_Festival;")
print(f"   --  {len(words)} words")
print("   pragma Style_Checks (Off);")
print("   Data : constant array (WNM.Speech.Word)")
print("     of not null LPC_Synth.LPC_Data_Const_Acc")
print("       := (")

for word in words:
    prefix = word[0:2] if len(word) >= 2 else word+word
    package = prefix.upper()

    if is_ada_keyword(prefix):
        package += "_K"

    end = "" if word == last_word else ","
    keyword = "_K" if is_ada_keyword(word) else ""
    print(f"           Vocab.{package}.{word.capitalize()}{keyword}'Access", end)
print("          );")

print("   Image : constant array (WNM.Speech.Word) of not null access String")
print("     := (")
for word in words:
    end = "" if word == last_word else ","
    print(f"         new String'(\"{word.capitalize()}\")", end)
print("        );")
print("end WNM.Speech_Dictionary;")