class Sign {
  final String signId;
  final String word;
  final String pronunciation;
  final String category;

  const Sign({
    required this.signId,
    required this.word,
    required this.pronunciation,
    required this.category,
  });

  String get videoAsset => 'assets/dictionary_videos/$signId.mov';
}

const List<Sign> kSignCatalog = [
  // Greetings (0-9)
  Sign(signId: '0',  word: 'Good Morning',     pronunciation: 'Magandang Umaga',              category: 'Greetings'),
  Sign(signId: '1',  word: 'Good Afternoon',   pronunciation: 'Magandang Hapon',              category: 'Greetings'),
  Sign(signId: '2',  word: 'Good Evening',     pronunciation: 'Magandang Gabi',               category: 'Greetings'),
  Sign(signId: '3',  word: 'Hello',            pronunciation: 'Kumusta',                      category: 'Greetings'),
  Sign(signId: '4',  word: 'How Are You',      pronunciation: 'Kumusta Ka',                   category: 'Greetings'),
  Sign(signId: '5',  word: "I'm Fine",         pronunciation: 'Mabuti Naman',                 category: 'Greetings'),
  Sign(signId: '6',  word: 'Nice To Meet You', pronunciation: 'Ikinagagalak Kitang Makilala', category: 'Greetings'),
  Sign(signId: '7',  word: 'Thank You',        pronunciation: 'Salamat',                      category: 'Greetings'),
  Sign(signId: '8',  word: "You're Welcome",   pronunciation: 'Walang Anuman',                category: 'Greetings'),
  Sign(signId: '9',  word: 'See You Tomorrow', pronunciation: 'Hanggang Bukas',               category: 'Greetings'),
  // Survival (10-19)
  Sign(signId: '10', word: 'Understand',        pronunciation: 'Naiintindihan',       category: 'Survival'),
  Sign(signId: '11', word: "Don't Understand",  pronunciation: 'Hindi Naiintindihan', category: 'Survival'),
  Sign(signId: '12', word: 'Know',              pronunciation: 'Alam',                category: 'Survival'),
  Sign(signId: '13', word: "Don't Know",        pronunciation: 'Hindi Alam',          category: 'Survival'),
  Sign(signId: '14', word: 'No',                pronunciation: 'Hindi',               category: 'Survival'),
  Sign(signId: '15', word: 'Yes',               pronunciation: 'Oo',                  category: 'Survival'),
  Sign(signId: '16', word: 'Wrong',             pronunciation: 'Mali',                category: 'Survival'),
  Sign(signId: '17', word: 'Correct',           pronunciation: 'Tama',                category: 'Survival'),
  Sign(signId: '18', word: 'Slow',              pronunciation: 'Mabagal',             category: 'Survival'),
  Sign(signId: '19', word: 'Fast',              pronunciation: 'Mabilis',             category: 'Survival'),
  // Numbers (20-29)
  Sign(signId: '20', word: 'One',   pronunciation: 'Isa',     category: 'Numbers'),
  Sign(signId: '21', word: 'Two',   pronunciation: 'Dalawa',  category: 'Numbers'),
  Sign(signId: '22', word: 'Three', pronunciation: 'Tatlo',   category: 'Numbers'),
  Sign(signId: '23', word: 'Four',  pronunciation: 'Apat',    category: 'Numbers'),
  Sign(signId: '24', word: 'Five',  pronunciation: 'Lima',    category: 'Numbers'),
  Sign(signId: '25', word: 'Six',   pronunciation: 'Anim',    category: 'Numbers'),
  Sign(signId: '26', word: 'Seven', pronunciation: 'Pito',    category: 'Numbers'),
  Sign(signId: '27', word: 'Eight', pronunciation: 'Walo',    category: 'Numbers'),
  Sign(signId: '28', word: 'Nine',  pronunciation: 'Siyam',   category: 'Numbers'),
  Sign(signId: '29', word: 'Ten',   pronunciation: 'Sampu',   category: 'Numbers'),
  // Days (42-51)
  Sign(signId: '42', word: 'Monday',    pronunciation: 'Lunes',      category: 'Days'),
  Sign(signId: '43', word: 'Tuesday',   pronunciation: 'Martes',     category: 'Days'),
  Sign(signId: '44', word: 'Wednesday', pronunciation: 'Miyerkules', category: 'Days'),
  Sign(signId: '45', word: 'Thursday',  pronunciation: 'Huwebes',    category: 'Days'),
  Sign(signId: '46', word: 'Friday',    pronunciation: 'Biyernes',   category: 'Days'),
  Sign(signId: '47', word: 'Saturday',  pronunciation: 'Sabado',     category: 'Days'),
  Sign(signId: '48', word: 'Sunday',    pronunciation: 'Linggo',     category: 'Days'),
  Sign(signId: '49', word: 'Today',     pronunciation: 'Ngayon',     category: 'Days'),
  Sign(signId: '50', word: 'Tomorrow',  pronunciation: 'Bukas',      category: 'Days'),
  Sign(signId: '51', word: 'Yesterday', pronunciation: 'Kahapon',    category: 'Days'),
  // Family (52-61)
  Sign(signId: '52', word: 'Father',      pronunciation: 'Ama / Tatay',     category: 'Family'),
  Sign(signId: '53', word: 'Mother',      pronunciation: 'Ina / Nanay',     category: 'Family'),
  Sign(signId: '54', word: 'Son',         pronunciation: 'Anak na Lalaki',  category: 'Family'),
  Sign(signId: '55', word: 'Daughter',    pronunciation: 'Anak na Babae',   category: 'Family'),
  Sign(signId: '56', word: 'Grandfather', pronunciation: 'Lolo',            category: 'Family'),
  Sign(signId: '57', word: 'Grandmother', pronunciation: 'Lola',            category: 'Family'),
  Sign(signId: '58', word: 'Uncle',       pronunciation: 'Tito',            category: 'Family'),
  Sign(signId: '59', word: 'Auntie',      pronunciation: 'Tita',            category: 'Family'),
  Sign(signId: '60', word: 'Cousin',      pronunciation: 'Pinsan',          category: 'Family'),
  Sign(signId: '61', word: 'Parents',     pronunciation: 'Magulang',        category: 'Family'),
];
