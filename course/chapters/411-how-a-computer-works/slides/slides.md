---
title: How a computer works
---

# How a computer works

Architecture & Deployment <!-- .element: class="subtitle" -->

**Notes:**

What a computer physically does when it runs a program, from the bottom up, and
what the processes of a deployment actually are.

---

## Binary

---

### The main components of a computer

<!-- TODO: diagram of the components; the room names them first. -->

- Processor (CPU)
- Memory (RAM)
- Storage
- Input and output
- The bus that connects them

**Notes:**

TODO.

---

### Eight bits

<p class="text-center font-mono text-6xl">0100 0001</p>

**Notes:**

TODO: eight bits, each 0 or 1, and nothing in them says what they mean.

---

### Eight bits, read three ways

<!-- TODO: lay the three readings out around the number. -->

<div class="grid grid-cols-3 items-center justify-items-center gap-8">
  <div class="text-5xl">65</div>
  <div class="text-center font-mono text-5xl">0100 0001</div>
  <div class="text-5xl">A</div>
  <div></div>
  <div class="h-24 w-24" style="background: rgb(73, 0, 85)"></div>
  <div></div>
</div>

**Notes:**

TODO: the same eight bits as an integer (65), as a letter in the ASCII and
UTF-8 tables (`A`), and as an 8-bit color (3 bits of red, 3 of green, 2 of
blue: `010`, `000`, `01`). "An instruction" is not one of the readings yet.

---

### An image is numbers

<!-- TODO: a small image, then zoomed in until its pixels show, then a few of
     its pixels as numbers. -->

**Notes:**

TODO: an image is a grid of pixels, and each pixel's color is a number.

---

### The ASCII table

<!-- .element: class="hidden" -->

<table class="mx-auto table-fixed font-mono text-sm">
  <tr>
    <td></td><td></td>
    <td colspan="3">
      <svg viewBox="0 0 300 40" class="w-full" aria-label="Plus 32">
        <path d="M50 36 V14 H250 V36" fill="none" stroke="#d9480f" stroke-width="3" />
        <path d="M243 28 L250 37 L257 28" fill="none" stroke="#d9480f" stroke-width="3" />
        <text x="150" y="10" text-anchor="middle" font-size="14" fill="#d9480f">+32</text>
      </svg>
    </td>
    <td></td>
  </tr>
  <tr>
    <td>SP <span class="opacity-50">32</span></td><td>0 <span class="opacity-50">48</span></td><td>&#64; <span class="opacity-50">64</span></td><td>P <span class="opacity-50">80</span></td><td>&#96; <span class="opacity-50">96</span></td><td>p <span class="opacity-50">112</span></td>
  </tr>
  <tr>
    <td>&#33; <span class="opacity-50">33</span></td><td>1 <span class="opacity-50">49</span></td><td class="bg-yellow-200 font-bold">A <span class="opacity-50">65</span></td><td>Q <span class="opacity-50">81</span></td><td class="bg-yellow-200 font-bold">a <span class="opacity-50">97</span></td><td>q <span class="opacity-50">113</span></td>
  </tr>
  <tr>
    <td>&#34; <span class="opacity-50">34</span></td><td>2 <span class="opacity-50">50</span></td><td>B <span class="opacity-50">66</span></td><td>R <span class="opacity-50">82</span></td><td>b <span class="opacity-50">98</span></td><td>r <span class="opacity-50">114</span></td>
  </tr>
  <tr>
    <td>&#35; <span class="opacity-50">35</span></td><td>3 <span class="opacity-50">51</span></td><td>C <span class="opacity-50">67</span></td><td>S <span class="opacity-50">83</span></td><td>c <span class="opacity-50">99</span></td><td>s <span class="opacity-50">115</span></td>
  </tr>
  <tr>
    <td>&#36; <span class="opacity-50">36</span></td><td>4 <span class="opacity-50">52</span></td><td>D <span class="opacity-50">68</span></td><td>T <span class="opacity-50">84</span></td><td>d <span class="opacity-50">100</span></td><td>t <span class="opacity-50">116</span></td>
  </tr>
  <tr>
    <td>&#37; <span class="opacity-50">37</span></td><td>5 <span class="opacity-50">53</span></td><td>E <span class="opacity-50">69</span></td><td>U <span class="opacity-50">85</span></td><td>e <span class="opacity-50">101</span></td><td>u <span class="opacity-50">117</span></td>
  </tr>
  <tr>
    <td>&#38; <span class="opacity-50">38</span></td><td>6 <span class="opacity-50">54</span></td><td>F <span class="opacity-50">70</span></td><td>V <span class="opacity-50">86</span></td><td>f <span class="opacity-50">102</span></td><td>v <span class="opacity-50">118</span></td>
  </tr>
  <tr>
    <td>&#39; <span class="opacity-50">39</span></td><td>7 <span class="opacity-50">55</span></td><td>G <span class="opacity-50">71</span></td><td>W <span class="opacity-50">87</span></td><td>g <span class="opacity-50">103</span></td><td>w <span class="opacity-50">119</span></td>
  </tr>
  <tr>
    <td>&#40; <span class="opacity-50">40</span></td><td>8 <span class="opacity-50">56</span></td><td>H <span class="opacity-50">72</span></td><td>X <span class="opacity-50">88</span></td><td>h <span class="opacity-50">104</span></td><td>x <span class="opacity-50">120</span></td>
  </tr>
  <tr>
    <td>&#41; <span class="opacity-50">41</span></td><td>9 <span class="opacity-50">57</span></td><td>I <span class="opacity-50">73</span></td><td>Y <span class="opacity-50">89</span></td><td>i <span class="opacity-50">105</span></td><td>y <span class="opacity-50">121</span></td>
  </tr>
  <tr>
    <td>&#42; <span class="opacity-50">42</span></td><td>&#58; <span class="opacity-50">58</span></td><td>J <span class="opacity-50">74</span></td><td>Z <span class="opacity-50">90</span></td><td>j <span class="opacity-50">106</span></td><td>z <span class="opacity-50">122</span></td>
  </tr>
  <tr>
    <td>&#43; <span class="opacity-50">43</span></td><td>&#59; <span class="opacity-50">59</span></td><td>K <span class="opacity-50">75</span></td><td>&#91; <span class="opacity-50">91</span></td><td>k <span class="opacity-50">107</span></td><td>&#123; <span class="opacity-50">123</span></td>
  </tr>
  <tr>
    <td>&#44; <span class="opacity-50">44</span></td><td>&#60; <span class="opacity-50">60</span></td><td>L <span class="opacity-50">76</span></td><td>&#92; <span class="opacity-50">92</span></td><td>l <span class="opacity-50">108</span></td><td>&#124; <span class="opacity-50">124</span></td>
  </tr>
  <tr>
    <td>&#45; <span class="opacity-50">45</span></td><td>&#61; <span class="opacity-50">61</span></td><td>M <span class="opacity-50">77</span></td><td>&#93; <span class="opacity-50">93</span></td><td>m <span class="opacity-50">109</span></td><td>&#125; <span class="opacity-50">125</span></td>
  </tr>
  <tr>
    <td>&#46; <span class="opacity-50">46</span></td><td>&#62; <span class="opacity-50">62</span></td><td>N <span class="opacity-50">78</span></td><td>&#94; <span class="opacity-50">94</span></td><td>n <span class="opacity-50">110</span></td><td>&#126; <span class="opacity-50">126</span></td>
  </tr>
  <tr>
    <td>&#47; <span class="opacity-50">47</span></td><td>&#63; <span class="opacity-50">63</span></td><td>O <span class="opacity-50">79</span></td><td>&#95; <span class="opacity-50">95</span></td><td>o <span class="opacity-50">111</span></td><td>DEL <span class="opacity-50">127</span></td>
  </tr>
</table>

**Notes:**

TODO: every letter has a code. The lowercase letters come 32 after the
uppercase ones: `A` is 65 and `a` is 97.

---

### Changing case is arithmetic

<!-- TODO: lay out side by side, with bit 5 highlighted. -->

| Letter | Integer |   Binary    |
| :----: | :-----: | :---------: |
|  `A`   |   65    | `0100 0001` |
|  `a`   |   97    | `0110 0001` |

**Notes:**

TODO: `a` is `A` plus 32, and 32 is the value of one bit, bit 5 counting
from 0. Changing case is adding or subtracting 32, which is flipping that
single bit. If we can manipulate numbers, we can manipulate any data.

---

## Electricity

---

### A closed circuit

<logic-diagram name="closed-circuit" controls="none" theme="light" style="width: 640px; margin: 0 auto">
</logic-diagram>

**Notes:**

A circuit is a loop: current leaves the battery from its `+` end, goes through
the switch and the lamp, and comes back to the battery's `-` end.

When the switch is open, the loop is broken and no current flows anywhere in
it, so the lamp stays dark. When the switch is closed, the loop is complete,
current flows and the lamp lights up.

---

### The electromagnet

<logic-diagram name="sounder-circuit" controls="none" theme="light" style="width: 640px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO: the same circuit with a sounder in place of the lamp. Current through a
coil makes an electromagnet, which pulls down an iron bar that clicks.

---

### The telegraph

<logic-diagram name="telegraph-two-wires" controls="none" theme="light" style="width: 800px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO: a circuit with a purpose: the same loop stretched between two towns, with
a key in place of the switch. It works over about 30 km, and needs a line there
and back.

---

### The earth as ground

<logic-diagram name="telegraph" controls="none" theme="light" style="width: 800px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO: the earth completes the circuit, which saves one of the two long wires.

---

### The telegraph repeater

<logic-diagram name="telegraph-repeater" controls="none" theme="light" style="width: 800px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO: the relay is a sounder that closes a contact instead of clicking, so a
weak current switches on a fresh one from a local battery, and the line goes
further.

---

### The ground symbol

<logic-diagram name="telegraph-repeater-grounds" controls="none" theme="light" style="width: 800px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO: shorthand for a stake in the earth.

---

### The source symbol

<logic-diagram name="telegraph-repeater-sources" controls="none" theme="light" style="width: 800px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO: a battery's `+` end alone, since its other end is in the ground anyway.

---

### The relay

<logic-diagram name="relay-single" controls="none" theme="light" style="width: 640px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO: a switch controlled by current.

---

## Logic

---

### A relay

<!-- .element: class="corner-title" -->

<div class="flex items-center justify-center gap-8">
  <logic-diagram id="relay-single" name="relay-single" controls="none" theme="light" style="width: 600px">
  </logic-diagram>
  <truth-table for="relay-single" theme="light"></truth-table>
</div>

**Notes:**

TODO: the simplest truth table: 0 in gives 0 out, 1 in gives 1 out.

---

### NOT

<!-- .element: class="corner-title fragment" -->

<div class="flex items-center justify-center gap-8">
  <logic-diagram id="relay-not" name="relay-not" controls="none" theme="light" style="width: 600px">
  </logic-diagram>
  <truth-table for="relay-not" theme="light"></truth-table>
</div>

**Notes:**

TODO: a relay whose contact is closed at rest.

---

### AND

<!-- .element: class="corner-title fragment" -->

<div class="flex items-center justify-center gap-8">
  <logic-diagram id="relay-and" name="relay-and" controls="none" theme="light" style="width: 600px">
  </logic-diagram>
  <truth-table for="relay-and" theme="light"></truth-table>
</div>

**Notes:**

TODO: two relays in series. The room gives the truth table before the demo
fills it.

---

### OR

<!-- .element: class="corner-title fragment" -->

<div class="flex items-center justify-center gap-8">
  <logic-diagram id="relay-or" name="relay-or" controls="none" theme="light" style="width: 600px">
  </logic-diagram>
  <truth-table for="relay-or" theme="light"></truth-table>
</div>

**Notes:**

TODO: two relays in parallel.

---

### XOR

<!-- .element: class="corner-title fragment" -->

<div class="flex items-center justify-center gap-8">
  <logic-diagram id="relay-xor" name="relay-xor" controls="none" theme="light" style="width: 600px">
  </logic-diagram>
  <truth-table for="relay-xor" theme="light"></truth-table>
</div>

**Notes:**

TODO: both contacts of each relay, wired like the two switches of a staircase
light: the lamp is lit when exactly one input is on. Left for students to play
with.

---

### The buffer and NOT symbols

<!-- .element: class="corner-title" -->

<div class="flex items-center justify-center gap-8">
  <logic-diagram id="buffer-and-not" name="buffer-and-not" controls="none" theme="light" style="width: 520px">
  </logic-diagram>
  <truth-table for="buffer-and-not" theme="light"></truth-table>
</div>

**Notes:**

TODO: a triangle stands for a relay. The buffer's lamp follows A, like the
single relay's; the NOT's does the opposite. The only difference between the
two symbols is the circle at the tip.

---

### The AND symbol

<!-- .element: class="corner-title" -->

<div class="flex items-center justify-center gap-8">
  <logic-diagram id="and-gate" name="and-gate" controls="none" theme="light" style="width: 520px">
  </logic-diagram>
  <truth-table for="and-gate" theme="light"></truth-table>
</div>

**Notes:**

TODO: the two relays in series, drawn as one symbol.

---

### The inversion bubble

<!-- .element: class="corner-title" -->

<div class="flex flex-col items-center justify-center gap-8">
  <logic-diagram id="inversion-bubble" name="inversion-bubble" controls="none" theme="light" style="width: 600px">
  </logic-diagram>
  <truth-table for="inversion-bubble" theme="light"></truth-table>
</div>

**Notes:**

TODO: an AND, the same AND followed by a NOT, and a NAND. NAND is the second
row with the NOT's triangle left out and its circle kept: the circle alone means
inversion. The last two lamps always agree.

---

### Logic gates

<!-- .element: class="hidden" -->

<div class="flex items-center justify-center gap-8">
  <logic-diagram id="gate-gallery" name="gate-gallery" controls="none" theme="light" style="width: 480px">
  </logic-diagram>
  <div class="flex flex-col gap-4">
    <truth-table for="gate-gallery" columns="A,BUFFER,NOT" theme="light"></truth-table>
    <truth-table for="gate-gallery" columns="A,B,AND,NAND" theme="light"></truth-table>
    <truth-table for="gate-gallery" columns="A,B,OR,NOR,XOR" theme="light"></truth-table>
  </div>
</div>

**Notes:**

TODO: the symbols that stand for the relay circuits from now on.

---

## Computing

---

### Adding in decimal

<table class="font-mono text-5xl">
  <tbody>
    <tr class="text-3xl text-red-500">
      <td class="!border-b-0 !px-2 !text-center"></td>
      <td class="!border-b-0 !px-2 !text-center"><span class="fragment" data-fragment-index="2">1</span></td>
      <td class="!border-b-0 !px-2 !text-center"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!border-b-0 !px-2 !text-center"></td>
    </tr>
    <tr>
      <td class="!border-b-0 !px-2 !text-center"></td>
      <td class="!border-b-0 !px-2 !text-center"></td>
      <td class="!border-b-0 !px-2 !text-center">5</td>
      <td class="!border-b-0 !px-2 !text-center">8</td>
    </tr>
    <tr>
      <td class="!border-b-0 !px-2 !text-center">+</td>
      <td class="!border-b-0 !px-2 !text-center"></td>
      <td class="!border-b-0 !px-2 !text-center">6</td>
      <td class="!border-b-0 !px-2 !text-center">7</td>
    </tr>
    <tr>
      <td class="!border-b-0 !px-2 !text-center !border-t-4 ![border-top-style:solid]"></td>
      <td class="!border-b-0 !px-2 !text-center !border-t-4 ![border-top-style:solid]"><span class="fragment" data-fragment-index="3">1</span></td>
      <td class="!border-b-0 !px-2 !text-center !border-t-4 ![border-top-style:solid]"><span class="fragment" data-fragment-index="2">2</span></td>
      <td class="!border-b-0 !px-2 !text-center !border-t-4 ![border-top-style:solid]"><span class="fragment" data-fragment-index="1">5</span></td>
    </tr>
  </tbody>
</table>

**Notes:**

Add column by column, from the right:

- Add the digits of the rightmost column: 8 + 7 = 15, which does not fit in one
  digit. Write the 5 and carry the 1 into the next column, the tens.
- The next column adds three digits, 5 + 6 and the carry, which makes 12: write
  the 2 and carry the 1 again.
- Nothing is left to add in the hundreds column but the carry, so it becomes the
  third digit. The final sum is 125.

This is classic **addition with carry**, the technique taught in school when you
learn to add multi-digit numbers.

---

### Adding in binary

<table class="font-mono text-5xl">
  <tbody>
    <tr class="text-3xl text-red-500">
      <td class="!border-b-0 !px-2 !text-center"></td>
      <td class="!border-b-0 !px-2 !text-center"><span class="fragment" data-fragment-index="3">1</span></td>
      <td class="!border-b-0 !px-2 !text-center"><span class="fragment" data-fragment-index="2">1</span></td>
      <td class="!border-b-0 !px-2 !text-center"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!border-b-0 !px-2 !text-center"></td>
    </tr>
    <tr>
      <td class="!border-b-0 !px-2 !text-center"></td>
      <td class="!border-b-0 !px-2 !text-center">0</td>
      <td class="!border-b-0 !px-2 !text-center">1</td>
      <td class="!border-b-0 !px-2 !text-center">1</td>
      <td class="!border-b-0 !px-2 !text-center relative">1<span class="fragment absolute left-full ml-16 w-[2ch] text-right text-blue-500" data-fragment-index="5">7</span></td>
    </tr>
    <tr>
      <td class="!border-b-0 !px-2 !text-center">+</td>
      <td class="!border-b-0 !px-2 !text-center">0</td>
      <td class="!border-b-0 !px-2 !text-center">0</td>
      <td class="!border-b-0 !px-2 !text-center">1</td>
      <td class="!border-b-0 !px-2 !text-center relative">1<span class="fragment absolute left-full ml-16 w-[2ch] text-right text-blue-500" data-fragment-index="5">3</span></td>
    </tr>
    <tr>
      <td class="!border-b-0 !px-2 !text-center !border-t-4 ![border-top-style:solid]"></td>
      <td class="!border-b-0 !px-2 !text-center !border-t-4 ![border-top-style:solid] relative"><span class="fragment" data-fragment-index="4">1</span><span class="fragment absolute top-full left-0 mt-2 w-full text-center text-2xl text-blue-500" data-fragment-index="5">2<sup>3</sup><br />8</span></td>
      <td class="!border-b-0 !px-2 !text-center !border-t-4 ![border-top-style:solid] relative"><span class="fragment" data-fragment-index="3">0</span><span class="fragment absolute top-full left-0 mt-2 w-full text-center text-2xl text-blue-500" data-fragment-index="5">2<sup>2</sup><br />4</span></td>
      <td class="!border-b-0 !px-2 !text-center !border-t-4 ![border-top-style:solid] relative"><span class="fragment" data-fragment-index="2">1</span><span class="fragment absolute top-full left-0 mt-2 w-full text-center text-2xl text-blue-500" data-fragment-index="5">2<sup>1</sup><br />2</span></td>
      <td class="!border-b-0 !px-2 !text-center relative !border-t-4 ![border-top-style:solid]"><span class="fragment" data-fragment-index="1">0</span><span class="fragment absolute left-full ml-16 w-[2ch] text-right text-blue-500" data-fragment-index="5">10</span><span class="fragment absolute top-full left-0 mt-2 w-full text-center text-2xl text-blue-500" data-fragment-index="5">2<sup>0</sup><br />1</span></td>
    </tr>
  </tbody>
</table>

**Notes:**

The same method, in binary instead of decimal, to add `0111` (7 in decimal) and
`0011` (3 in decimal):

- In the rightmost column, `1` + `1` = `10` in binary (2 in decimal): write the
  0 and carry the 1, as 8 + 7 = 15 does in decimal.
- In the next column adds three bits, 1 + 1 and the carry, which makes `11` in
  binary (3 in decimal): write a 1 and carry a 1.
- In the next column, 0 + 1 and the carry makes `10` in binary (2 in decimal):
  write a 0 and carry a 1.
- The carry goes into the final column. 0 + 0 and the carry makes `1` in binary
  (1 in decimal). The final sum is `1010` (10 in decimal).

Every column does the same thing: it adds two bits and the carry from the column
on its right, and gives a sum bit and a carry for the column on its left.

---

### The sum and carry of two bits

<div class="flex items-start justify-center gap-28">
  <div class="flex flex-col items-center gap-6">
    <table class="fragment !m-0 font-mono text-4xl font-bold text-[#1d1d1f]" data-fragment-index="1">
      <thead>
        <tr>
          <th class="!px-[0.5em] !py-[0.2em] !text-center font-sans font-semibold ![border-bottom:2px_solid_#1d1d1f]">A</th>
          <th class="!px-[0.5em] !py-[0.2em] !text-center font-sans font-semibold ![border-bottom:2px_solid_#1d1d1f]">B</th>
          <th class="!px-[0.5em] !py-[0.2em] !text-center font-sans font-semibold ![border-bottom:2px_solid_#1d1d1f] ![border-left:3px_solid_#1d1d1f]">Sum</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8]">0</td>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8]">0</td>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8] ![border-left:3px_solid_#1d1d1f]"><span class="inline-block min-w-[1.4em] rounded-[0.3em]">0</span></td>
        </tr>
        <tr>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8]">0</td>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8]">1</td>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8] ![border-left:3px_solid_#1d1d1f]"><span class="inline-block min-w-[1.4em] rounded-[0.3em] bg-[#fff3bf]">1</span></td>
        </tr>
        <tr>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8]">1</td>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8]">0</td>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8] ![border-left:3px_solid_#1d1d1f]"><span class="inline-block min-w-[1.4em] rounded-[0.3em] bg-[#fff3bf]">1</span></td>
        </tr>
        <tr>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8]">1</td>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8]">1</td>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8] ![border-left:3px_solid_#1d1d1f]"><span class="inline-block min-w-[1.4em] rounded-[0.3em]">0</span></td>
        </tr>
      </tbody>
    </table>
    <p class="fragment !m-0 text-4xl font-bold text-blue-500" data-fragment-index="3">XOR</p>
  </div>
  <div class="flex flex-col items-center gap-6">
    <table class="fragment !m-0 font-mono text-4xl font-bold text-[#1d1d1f]" data-fragment-index="2">
      <thead>
        <tr>
          <th class="!px-[0.5em] !py-[0.2em] !text-center font-sans font-semibold ![border-bottom:2px_solid_#1d1d1f]">A</th>
          <th class="!px-[0.5em] !py-[0.2em] !text-center font-sans font-semibold ![border-bottom:2px_solid_#1d1d1f]">B</th>
          <th class="!px-[0.5em] !py-[0.2em] !text-center font-sans font-semibold ![border-bottom:2px_solid_#1d1d1f] ![border-left:3px_solid_#1d1d1f]">Carry</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8]">0</td>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8]">0</td>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8] ![border-left:3px_solid_#1d1d1f]"><span class="inline-block min-w-[1.4em] rounded-[0.3em]">0</span></td>
        </tr>
        <tr>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8]">0</td>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8]">1</td>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8] ![border-left:3px_solid_#1d1d1f]"><span class="inline-block min-w-[1.4em] rounded-[0.3em]">0</span></td>
        </tr>
        <tr>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8]">1</td>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8]">0</td>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8] ![border-left:3px_solid_#1d1d1f]"><span class="inline-block min-w-[1.4em] rounded-[0.3em]">0</span></td>
        </tr>
        <tr>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8]">1</td>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8]">1</td>
          <td class="!px-[0.5em] !py-[0.15em] !text-center ![border-bottom:1px_solid_#a3a3a8] ![border-left:3px_solid_#1d1d1f]"><span class="inline-block min-w-[1.4em] rounded-[0.3em] bg-[#fff3bf]">1</span></td>
        </tr>
      </tbody>
    </table>
    <p class="fragment !m-0 text-4xl font-bold text-blue-500" data-fragment-index="4">AND</p>
  </div>
</div>

**Notes:**

Adding two bits, as in the rightmost column of a binary addition, gives two
bits: a sum and a carry. The sum is 1 when exactly one of the two bits is 1.
The carry is 1 only when both are, since 1 + 1 = `10` in binary.

As you may or may not have noticed, it just so happens that these are exactly
the truth tables of XOR and AND.

---

### The half adder

<!-- .element: class="corner-title" -->

<logic-diagram id="half-adder" name="half-adder" names="true" controls="none" theme="light" style="width: 700px; margin: 0 auto">
</logic-diagram>
<truth-table for="half-adder" theme="light"></truth-table>

**Notes:**

The binary sum and carry truth tables, built with logic gates: A and B go into
both an XOR and an AND. The XOR gives the sum bit, `S`, and the AND gives the
carry bit, `Cout` ("carry out"), which goes out to the next column on the left.

It is only half an adder because it adds two bits and nothing else. That is
enough for the rightmost column of an addition, but every other column also has
to add the carry coming in from the column on its right.

---

### The full adder

<!-- .element: class="corner-title" -->

<logic-diagram id="full-adder" name="full-adder" names="true" controls="none" theme="light" style="width: 960px; margin: 0 auto">
</logic-diagram>
<truth-table for="full-adder" split="2" theme="light"></truth-table>

**Notes:**

A full adder adds three bits: A, B and the carry in, `Cin`, from the column on
its right. It is two half adders and an OR gate:

- The first half adder, on the left, adds A and B, as in the previous circuit.
- The second half adder, in the middle, adds the carry in to the first sum bit.
  Its sum is the full adder's sum bit, `S`.
- Each half adder can produce a carry, and the OR combines them: the carry out,
  `Cout`, is 1 when either one carries. The first carries when A and B are both
  1, the second when exactly one of them is 1 and so is the carry in. Put
  simply, the carry out is 1 when at least two of the three inputs are 1.

The two half adders never carry at the same time: when A and B are both 1, their
sum bit is 0, so the second half adder has nothing to carry. That is why a plain
OR is enough to combine them. When all three inputs are 1, the first half adder
carries and the second one's sum is 1: `S` and `Cout` are both 1, which is
`11` in binary, 3.

---

### The full adder as a block

<!-- .element: class="hidden" -->

<logic-diagram name="full-adder-block" names="true" controls="none" theme="light" style="width: 480px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO.

---

### A 4-bit ripple-carry adder

<!-- .element: class="hidden" -->

<!-- TODO: the design lists this one as supplementary material, not shown in
     the session. -->

<logic-diagram name="four-bit-adder" names="true" controls="none" theme="light" style="width: 900px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO: four full adders, the carry rippling from right to left.

---

## Remembering

---

### Feedback: the SR latch

<!-- .element: class="hidden" -->

<logic-diagram name="sr-latch" names="true" controls="none" theme="light" style="width: 640px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO: memory from feedback, an output wired back into an input.

---

### The D latch

<!-- .element: class="hidden" -->

<logic-diagram name="d-latch" names="true" controls="none" theme="light" style="width: 800px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO: storing a data bit on demand.

---

### The D latch as a block

<!-- .element: class="hidden" -->

<logic-diagram name="d-latch-block" names="true" controls="none" theme="light" style="width: 480px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO.

---

### The selector

<!-- .element: class="hidden" -->

<logic-diagram name="selector" names="true" controls="none" theme="light" style="width: 640px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO: choosing which input reaches the output.

---

### The decoder

<!-- .element: class="hidden" -->

<logic-diagram name="decoder-2-to-4" names="true" controls="none" theme="light" style="width: 640px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO: routing a signal to the addressed output.

---

### The decoder as a block

<!-- .element: class="hidden" -->

<logic-diagram name="decoder-block" names="true" controls="none" theme="light" style="width: 480px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO.

---

### The 4-to-1 selector

<!-- .element: class="hidden" -->

<logic-diagram name="selector-4-to-1" names="true" controls="none" theme="light" style="width: 640px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO: the same idea with more inputs.

---

### The selector as a block

<!-- .element: class="hidden" -->

<logic-diagram name="selector-block" names="true" controls="none" theme="light" style="width: 480px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO.

---

### Addressable memory

<!-- .element: class="hidden" -->

<logic-diagram name="addressable-memory" names="true" controls="none" theme="light" style="width: 530px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO: writing and reading a cell by its address. Two address bits give four
cells of one bit each.

---

### A 4-bit address gives a 16-byte memory

<!-- TODO: the cells' contents, if any, for the trace. -->

<div class="grid grid-cols-4 gap-2 font-mono">
  <div class="border p-2">0000</div>
  <div class="border p-2">0001</div>
  <div class="border p-2">0010</div>
  <div class="border p-2">0011</div>
  <div class="border p-2">0100</div>
  <div class="border p-2">0101</div>
  <div class="border p-2">0110</div>
  <div class="border p-2">0111</div>
  <div class="border p-2">1000</div>
  <div class="border p-2">1001</div>
  <div class="border p-2">1010</div>
  <div class="border p-2">1011</div>
  <div class="border p-2">1100</div>
  <div class="border p-2">1101</div>
  <div class="border p-2">1110</div>
  <div class="border p-2">1111</div>
</div>

**Notes:**

TODO: 4 address bits give 2⁴ = 16 addresses, and each addressed cell holds 8
bits.

---

## Ticking

---

### The buzzer

<!-- .element: class="hidden" -->

<logic-diagram name="relay-buzzer" controls="none" theme="light" style="width: 640px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO: a relay feeding its own coil. Where a clock comes from.

---

### The oscillator

<!-- .element: class="hidden" -->

<logic-diagram name="not-oscillator" names="true" controls="none" theme="light" style="width: 560px; margin: 0 auto">
</logic-diagram>

**Notes:**

The buzzer, drawn with a gate. A relay feeding its own coil through its normally
closed contact is a NOT gate whose output goes back to its input. Its output
never agrees with its input, so it keeps flipping, as fast as the gate can
switch. A circuit whose output keeps switching back and forth on its own is an
oscillator.

---

### The clock

<!-- .element: class="hidden" -->

<logic-diagram name="clock-lamp" names="true" controls="none" theme="light" style="width: 480px; margin: 0 auto">
</logic-diagram>

**Notes:**

An oscillator that switches at a steady pace is a computer's clock, drawn from
now on as this symbol. Every tick of the clock moves the computer on by one
step.

A real computer's clock does not use a NOT gate, whose pace drifts with
temperature and voltage: it uses a quartz crystal, which vibrates at a very
stable frequency, billions of ticks per second in a modern processor.

---

## Counting

---

### The edge-triggered D flip-flop

<!-- .element: class="hidden" -->

<!-- TODO: shown as a frequency divider, but no diagram wires Q̅ back to D yet:
     d-flip-flop-manual has D as a toggle. -->

<logic-diagram name="d-flip-flop-manual" names="true" controls="none" theme="light" style="width: 900px; margin: 0 auto">
</logic-diagram>

**Notes:**

TODO: Q only changes when the clock rises. With Q̅ fed back into D, it changes
on every other tick: half the clock's frequency.

---

### Two latches make a flip-flop

<!-- .element: class="hidden" -->

<logic-diagram name="d-flip-flop-latches" names="true" controls="none" theme="light" style="width: 720px; margin: 0 auto">
</logic-diagram>

**Notes:**

The edge-triggered D flip-flop is two D latches in a row, and a NOT gate. The
first latch gets D, and the clock through the NOT: it is open, following D,
while the clock is low. The second latch gets the first one's Q, and the clock
directly: it is open while the clock is high, and copies the first latch.

The two latches are never open together, so D never runs straight through to Q.
When the clock rises, the first latch closes on the value D had just before, and
the second one opens and passes that value on to Q. Q only changes when the
clock rises.

---

### The D flip-flop as a block

<!-- .element: class="hidden" -->

<logic-diagram name="d-flip-flop-block-manual" names="true" controls="none" theme="light" style="width: 480px; margin: 0 auto">
</logic-diagram>

**Notes:**

The same flip-flop drawn as a box, as the counter will use it. The wedge on the
clock input marks it as edge-triggered: Q only takes D's value when CLK rises.

---

### Dividing the frequency

<!-- .element: class="hidden" -->

<logic-diagram name="frequency-divider" names="true" controls="none" theme="light" style="width: 400px; margin: 0 auto">
</logic-diagram>

<table class="mt-8 text-[#1d1d1f]">
  <tbody>
    <tr>
      <th class="!border-b-0 !py-0 !pr-6 !text-right align-middle font-sans text-3xl">CLK</th>
      <td class="!p-0 w-14 h-12 !text-center align-middle font-mono text-3xl ![border-bottom:4px_solid_currentColor]"></td>
      <td class="!p-0 w-14 h-12 !text-center align-middle font-mono text-3xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-14 h-12 !text-center align-middle font-mono text-3xl ![border-bottom:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-14 h-12 !text-center align-middle font-mono text-3xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-14 h-12 !text-center align-middle font-mono text-3xl ![border-bottom:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-14 h-12 !text-center align-middle font-mono text-3xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-14 h-12 !text-center align-middle font-mono text-3xl ![border-bottom:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-14 h-12 !text-center align-middle font-mono text-3xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
    </tr>
    <tr>
      <td class="!border-b-0 !p-0 h-6" colspan="9"></td>
    </tr>
    <tr>
      <th class="!border-b-0 !py-0 !pr-6 !text-right align-middle font-sans text-3xl">Q</th>
      <td class="!p-0 w-14 h-12 !text-center align-middle font-mono text-3xl ![border-bottom:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-14 h-12 !text-center align-middle font-mono text-3xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-14 h-12 !text-center align-middle font-mono text-3xl !border-b-0 ![border-top:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-14 h-12 !text-center align-middle font-mono text-3xl ![border-bottom:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-14 h-12 !text-center align-middle font-mono text-3xl ![border-bottom:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-14 h-12 !text-center align-middle font-mono text-3xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-14 h-12 !text-center align-middle font-mono text-3xl !border-b-0 ![border-top:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-14 h-12 !text-center align-middle font-mono text-3xl ![border-bottom:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
    </tr>
  </tbody>
</table>

**Notes:**

A D flip-flop feeding its Q̅ back into its D: on every rising edge of the clock,
it stores the opposite of what it holds, so Q flips. Q therefore goes through one
full cycle, off then on, for every two cycles of the clock: half the clock's
frequency.

The timing diagram underneath shows it, with time running from left to right.
Each time CLK steps up, Q steps, up or down. A real flip-flop takes a moment to
respond, which the drawing leaves out.

Q goes 0, 1, 0, 1, one step per cycle of the clock: it counts, but with a single
binary digit. To count higher, halve the frequency again: a second flip-flop
gives the next digit.

---

### The counter

<!-- .element: class="hidden" -->

<logic-diagram name="counter" names="true" controls="none" theme="light" style="width: 760px; margin: 0 auto">
</logic-diagram>

<table class="mt-8 text-[#1d1d1f]">
  <tbody>
    <tr>
      <th class="!border-b-0 !py-0 !pr-6 !text-right align-middle font-sans text-2xl">CLK</th>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor]"></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"></td>
    </tr>
    <tr>
      <td class="!border-b-0 !p-0 h-6" colspan="17"></td>
    </tr>
    <tr>
      <th class="!border-b-0 !py-0 !pr-6 !text-right align-middle font-sans text-2xl">Q0</th>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
    </tr>
    <tr>
      <td class="!border-b-0 !p-0 h-6" colspan="17"></td>
    </tr>
    <tr>
      <th class="!border-b-0 !py-0 !pr-6 !text-right align-middle font-sans text-2xl">Q1</th>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
    </tr>
    <tr>
      <td class="!border-b-0 !p-0 h-6" colspan="17"></td>
    </tr>
    <tr>
      <th class="!border-b-0 !py-0 !pr-6 !text-right align-middle font-sans text-2xl">Q2</th>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl !border-b-0 ![border-top:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">1</span></td>
      <td class="!p-0 w-8 h-10 !text-center align-middle font-mono text-2xl ![border-bottom:4px_solid_currentColor] ![border-left:4px_solid_currentColor]"><span class="fragment" data-fragment-index="1">0</span></td>
    </tr>
    <tr>
      <td class="!border-b-0 !p-0 h-6" colspan="17"></td>
    </tr>
    <tr>
      <th class="!border-b-0 !py-0 !pr-6"></th>
      <td class="!border-b-0 !p-0 w-8 h-10 !text-center align-middle font-mono text-2xl text-blue-500"></td>
      <td class="!border-b-0 !p-0 w-8 h-10 !text-center align-middle font-mono text-2xl text-blue-500"><span class="fragment" data-fragment-index="2">1</span></td>
      <td class="!border-b-0 !p-0 w-8 h-10 !text-center align-middle font-mono text-2xl text-blue-500"></td>
      <td class="!border-b-0 !p-0 w-8 h-10 !text-center align-middle font-mono text-2xl text-blue-500"><span class="fragment" data-fragment-index="2">2</span></td>
      <td class="!border-b-0 !p-0 w-8 h-10 !text-center align-middle font-mono text-2xl text-blue-500"></td>
      <td class="!border-b-0 !p-0 w-8 h-10 !text-center align-middle font-mono text-2xl text-blue-500"><span class="fragment" data-fragment-index="2">3</span></td>
      <td class="!border-b-0 !p-0 w-8 h-10 !text-center align-middle font-mono text-2xl text-blue-500"></td>
      <td class="!border-b-0 !p-0 w-8 h-10 !text-center align-middle font-mono text-2xl text-blue-500"><span class="fragment" data-fragment-index="2">4</span></td>
      <td class="!border-b-0 !p-0 w-8 h-10 !text-center align-middle font-mono text-2xl text-blue-500"></td>
      <td class="!border-b-0 !p-0 w-8 h-10 !text-center align-middle font-mono text-2xl text-blue-500"><span class="fragment" data-fragment-index="2">5</span></td>
      <td class="!border-b-0 !p-0 w-8 h-10 !text-center align-middle font-mono text-2xl text-blue-500"></td>
      <td class="!border-b-0 !p-0 w-8 h-10 !text-center align-middle font-mono text-2xl text-blue-500"><span class="fragment" data-fragment-index="2">6</span></td>
      <td class="!border-b-0 !p-0 w-8 h-10 !text-center align-middle font-mono text-2xl text-blue-500"></td>
      <td class="!border-b-0 !p-0 w-8 h-10 !text-center align-middle font-mono text-2xl text-blue-500"><span class="fragment" data-fragment-index="2">7</span></td>
      <td class="!border-b-0 !p-0 w-8 h-10 !text-center align-middle font-mono text-2xl text-blue-500"></td>
      <td class="!border-b-0 !p-0 w-8 h-10 !text-center align-middle font-mono text-2xl text-blue-500"><span class="fragment" data-fragment-index="2">0</span></td>
    </tr>
  </tbody>
</table>

**Notes:**

Three frequency dividers in a chain. The first is clocked by the clock, and each
next one by the Q̅ of the one before, so each flips when the one before goes
back to 0, and runs at half its frequency.

Read each column of the timing diagram from the bottom up, Q2 then Q1 then Q0,
as a binary number: `000`, `001`, `010`, `011` … up to `111`, then `000` again.
The counter adds 1 on every clock cycle. A computer's program counter works the
same way, with more digits.

---

## Instructions

---

### The instruction set

<!-- TODO: only LOAD = 0001 is fixed (LOAD 14 is 0001 1110); the other
     encodings are placeholders to decide. -->

| Operation | Code   | Effect                |
| --------- | ------ | --------------------- |
| `LOAD x`  | `0001` | acc ← memory[x]       |
| `STORE x` | `????` | memory[x] ← acc       |
| `ADD x`   | `????` | acc ← acc + memory[x] |
| `SUB x`   | `????` | acc ← acc − memory[x] |
| `JUMP x`  | `????` | go to x               |
| `JUMPZ x` | `????` | if acc = 0, go to x   |
| `HALT`    | `????` | stop                  |

**Notes:**

TODO: an instruction is 4 bits of operation and 4 bits of address: eight bits,
read one more way.
