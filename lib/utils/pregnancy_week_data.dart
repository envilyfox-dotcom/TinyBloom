// Shared week-by-week pregnancy data: size, weight, length and a
// development highlight for each week (1-40). Single source of truth used
// by both the Dashboard (pregnancy card, active alerts) and the Baby
// Development screen, so they never disagree with each other.
const pregnancyWeekData = {
  1: {
    'size': 'a poppy seed',
    'emoji': '🌱',
    'weight': '< 1g',
    'length': '< 1 mm',
    'highlight': 'Fertilisation occurs. The journey begins!'
  },
  2: {
    'size': 'a sesame seed',
    'emoji': '🌱',
    'weight': '< 1g',
    'length': '< 1 mm',
    'highlight': 'The blastocyst implants into the uterine wall.'
  },
  3: {
    'size': 'a sesame seed',
    'emoji': '🌿',
    'weight': '< 1g',
    'length': '< 1 mm',
    'highlight': 'The neural tube — brain and spinal cord — begins forming.'
  },
  4: {
    'size': 'a poppy seed',
    'emoji': '🌿',
    'weight': '< 1g',
    'length': '0.4 cm',
    'highlight': 'The heart starts beating. Arm and leg buds appear.'
  },
  5: {
    'size': 'an apple seed',
    'emoji': '🫘',
    'weight': '< 1g',
    'length': '0.5 cm',
    'highlight': 'Facial features begin to take shape. Eyes and ears forming.'
  },
  6: {
    'size': 'a pea',
    'emoji': '🫛',
    'weight': '< 1g',
    'length': '0.6 cm',
    'highlight': 'Brain waves can be detected. Fingers and toes forming.'
  },
  7: {
    'size': 'a blueberry',
    'emoji': '🫐',
    'weight': '< 1g',
    'length': '1.3 cm',
    'highlight': 'Baby is moving! Though too small to feel yet.'
  },
  8: {
    'size': 'a kidney bean',
    'emoji': '🫘',
    'weight': '1g',
    'length': '1.6 cm',
    'highlight': 'All essential organs have begun forming.'
  },
  9: {
    'size': 'a grape',
    'emoji': '🍇',
    'weight': '2g',
    'length': '2.3 cm',
    'highlight': 'Baby can make a fist. Eyelids are fused shut.'
  },
  10: {
    'size': 'a strawberry',
    'emoji': '🍓',
    'weight': '4g',
    'length': '3.1 cm',
    'highlight': 'Baby is now officially a foetus. Tiny fingernails forming.'
  },
  11: {
    'size': 'a fig',
    'emoji': '🌰',
    'weight': '7g',
    'length': '4.1 cm',
    'highlight': 'Baby can open and close their fists.'
  },
  12: {
    'size': 'a lime',
    'emoji': '🍋',
    'weight': '14g',
    'length': '5.4 cm',
    'highlight':
        'Reflexes are developing. You may see movement on ultrasound.'
  },
  13: {
    'size': 'a peach',
    'emoji': '🍑',
    'weight': '23g',
    'length': '7.4 cm',
    'highlight': 'Vocal cords forming. Baby can suck their thumb.'
  },
  14: {
    'size': 'a lemon',
    'emoji': '🍋',
    'weight': '43g',
    'length': '8.7 cm',
    'highlight': 'Baby\'s facial muscles allow for expressions.'
  },
  15: {
    'size': 'an apple',
    'emoji': '🍎',
    'weight': '70g',
    'length': '10.1 cm',
    'highlight': 'Bones are hardening. Baby can sense light.'
  },
  16: {
    'size': 'an avocado',
    'emoji': '🥑',
    'weight': '100g',
    'length': '11.6 cm',
    'highlight': 'You may feel the first flutters of movement (quickening).'
  },
  17: {
    'size': 'a pear',
    'emoji': '🍐',
    'weight': '140g',
    'length': '13 cm',
    'highlight': 'Baby\'s skeleton is changing from cartilage to bone.'
  },
  18: {
    'size': 'a bell pepper',
    'emoji': '🫑',
    'weight': '190g',
    'length': '14.2 cm',
    'highlight': 'Baby can hear your voice! Keep talking and singing.'
  },
  19: {
    'size': 'a mango',
    'emoji': '🥭',
    'weight': '240g',
    'length': '15.3 cm',
    'highlight': 'A protective coating (vernix) covers baby\'s skin.'
  },
  20: {
    'size': 'a banana',
    'emoji': '🍌',
    'weight': '300g',
    'length': '25.6 cm',
    'highlight': 'Halfway there! Baby\'s movements are becoming stronger.'
  },
  21: {
    'size': 'a carrot',
    'emoji': '🥕',
    'weight': '360g',
    'length': '26.7 cm',
    'highlight':
        'Baby can swallow amniotic fluid, helping digestive development.'
  },
  22: {
    'size': 'a coconut',
    'emoji': '🥥',
    'weight': '430g',
    'length': '27.8 cm',
    'highlight': 'Eyebrows and eyelashes are now visible.'
  },
  23: {
    'size': 'a large mango',
    'emoji': '🥭',
    'weight': '500g',
    'length': '28.9 cm',
    'highlight': 'Baby is gaining weight rapidly. Lungs developing.'
  },
  24: {
    'size': 'an ear of corn',
    'emoji': '🌽',
    'weight': '600g',
    'length': '30 cm',
    'highlight': 'Baby\'s face is fully formed. Fingerprints are unique now.'
  },
  25: {
    'size': 'a cauliflower',
    'emoji': '🥦',
    'weight': '660g',
    'length': '34.6 cm',
    'highlight': 'Baby responds to familiar sounds, especially your voice.'
  },
  26: {
    'size': 'a scallion',
    'emoji': '🧅',
    'weight': '760g',
    'length': '35.6 cm',
    'highlight': 'Eyes can open and close. Baby may hiccup regularly.'
  },
  27: {
    'size': 'a head of lettuce',
    'emoji': '🥬',
    'weight': '875g',
    'length': '36.6 cm',
    'highlight': 'Brain tissue developing rapidly. Baby has sleep cycles.'
  },
  28: {
    'size': 'an eggplant',
    'emoji': '🍆',
    'weight': '1.0kg',
    'length': '37.6 cm',
    'highlight': 'Third trimester begins! Baby can blink and has eyelashes.'
  },
  29: {
    'size': 'a butternut squash',
    'emoji': '🎃',
    'weight': '1.15kg',
    'length': '38.6 cm',
    'highlight':
        'Baby\'s head is growing to accommodate the developing brain.'
  },
  30: {
    'size': 'a cabbage',
    'emoji': '🥬',
    'weight': '1.3kg',
    'length': '39.9 cm',
    'highlight': 'Baby is storing iron, calcium and phosphorus.'
  },
  31: {
    'size': 'a coconut',
    'emoji': '🥥',
    'weight': '1.5kg',
    'length': '41.1 cm',
    'highlight': 'Baby\'s brain can control body temperature.'
  },
  32: {
    'size': 'a jícama',
    'emoji': '🫚',
    'weight': '1.7kg',
    'length': '42.4 cm',
    'highlight': 'Baby practices breathing movements to prepare for birth.'
  },
  33: {
    'size': 'a pineapple',
    'emoji': '🍍',
    'weight': '1.9kg',
    'length': '43.7 cm',
    'highlight':
        'Bones are hardening except for the skull (stays flexible for birth).'
  },
  34: {
    'size': 'a cantaloupe',
    'emoji': '🍈',
    'weight': '2.1kg',
    'length': '45 cm',
    'highlight': 'Baby\'s immune system is strengthening.'
  },
  35: {
    'size': 'a honeydew melon',
    'emoji': '🍈',
    'weight': '2.4kg',
    'length': '46.2 cm',
    'highlight': 'Most babies settle into a head-down position now.'
  },
  36: {
    'size': 'a head of romaine',
    'emoji': '🥬',
    'weight': '2.6kg',
    'length': '47.4 cm',
    'highlight': 'Baby is considered early-term. Lungs are nearly mature.'
  },
  37: {
    'size': 'a bunch of chard',
    'emoji': '🌿',
    'weight': '2.8kg',
    'length': '48.6 cm',
    'highlight':
        'Full-term in 3 weeks. Baby is practising breathing, sucking and blinking.'
  },
  38: {
    'size': 'a leek',
    'emoji': '🫛',
    'weight': '3.0kg',
    'length': '49.8 cm',
    'highlight':
        'Baby is building a layer of fat to regulate temperature after birth.'
  },
  39: {
    'size': 'a mini watermelon',
    'emoji': '🍉',
    'weight': '3.3kg',
    'length': '50.7 cm',
    'highlight':
        'Baby\'s brain and lungs continue maturing right up to birth.'
  },
  40: {
    'size': 'a small pumpkin',
    'emoji': '🎃',
    'weight': '3.4kg',
    'length': '51.2 cm',
    'highlight':
        'Full term! Baby could arrive any day. You\'ve done amazingly.'
  },
};
