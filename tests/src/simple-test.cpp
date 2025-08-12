#include <iostream>
#include <string>
#include <sstream>

#include "console.hpp"

#define println console::println

// For ICU functionality
#include <unicode/uvernum.h>
#include <unicode/uversion.h>
#include <unicode/unistr.h>
#include <unicode/ucnv.h>
#include <unicode/ubrk.h>
#include <unicode/translit.h>
#include <unicode/locid.h>
#include <unicode/numfmt.h>
#include <unicode/calendar.h>
#include <unicode/datefmt.h>
#include <unicode/brkiter.h>
#include <unicode/uclean.h>
#include <unicode/udata.h>
#include <unicode/ucal.h>
#include <unicode/uchar.h>
#include <unicode/ures.h>
#include <unicode/coll.h>
#include <unicode/resbund.h>
#include <unicode/stringpiece.h>  // for UnicodeString::fromUTF8

// Example 1: Unicode string operations
void runStringExample() {
    println();
    println("=== Running Unicode String Example ===");

    // Helper function to convert UnicodeString to std::string for output
    auto toString = [](const icu::UnicodeString& ustr) -> std::string {
        std::string result;
        ustr.toUTF8String(result);
        return result;
    };

    // Create a Unicode string with multi-language text (decode as UTF-8 explicitly)
    icu::UnicodeString ustr = icu::UnicodeString::fromUTF8("Hello, World! こんにちは 你好 مرحبا");
    println("Original string: {}", toString(ustr));

    // Get string properties
    println("Length: {} Unicode units", ustr.length());

    // Convert to uppercase
    icu::UnicodeString upper(ustr);
    upper.toUpper();
    println("Uppercase: {}", toString(upper));

    // Convert to lowercase
    icu::UnicodeString lower(ustr);
    lower.toLower();
    println("Lowercase: {}", toString(lower));
}

// Example 2: Locale and formatting
void runLocaleExample() {
    std::cout << "\n=== Running Locale Example ===" << std::endl;
    
    // Helper function to convert UnicodeString to std::string for output
    auto toString = [](const icu::UnicodeString& ustr) -> std::string {
        std::string result;
        ustr.toUTF8String(result);
        return result;
    };
    
    // Create locales
    icu::Locale us("en_US");
    icu::Locale fr("fr_FR");
    icu::Locale jp("ja_JP");
    
    // Create UnicodeString objects to store display names
    icu::UnicodeString usName, frName, jpName;
    
    // Display locale information
    println("US Locale:       {} ({})", us.getName(), toString(us.getDisplayName(usName)));
    println("French Locale:   {} ({})", fr.getName(), toString(fr.getDisplayName(frName)));
    println("Japanese Locale: {} ({})", jp.getName(), toString(jp.getDisplayName(jpName)));
    
    // Number formatting
    UErrorCode status = U_ZERO_ERROR;
    std::unique_ptr<icu::NumberFormat> nf_us(icu::NumberFormat::createCurrencyInstance(us, status));
    std::unique_ptr<icu::NumberFormat> nf_fr(icu::NumberFormat::createCurrencyInstance(fr, status));
    std::unique_ptr<icu::NumberFormat> nf_jp(icu::NumberFormat::createCurrencyInstance(jp, status));
    
    double amount = 1234567.89;
    icu::UnicodeString result_us, result_fr, result_jp;
    
    if (U_SUCCESS(status)) {
        nf_us->format(amount, result_us);
        nf_fr->format(amount, result_fr);
        nf_jp->format(amount, result_jp);
        
        println("Currency formatting:");
        println("  US: {}",     toString(result_us));
        println("  France: {}", toString(result_fr));
        println("  Japan: {}",  toString(result_jp));
    }
}
    
// Example 3: Text boundary analysis
void runBreakIteratorExample() {
    println("\n=== Running Break Iterator Example ===");
    
    // Helper function to convert UnicodeString to std::string for output
    auto toString = [](const icu::UnicodeString& ustr) -> std::string {
        std::string result;
        ustr.toUTF8String(result);
        return result;
    };
    
    UErrorCode status = U_ZERO_ERROR;
    icu::UnicodeString text = icu::UnicodeString::fromUTF8("Hello, world! This is a test. How are you? 你好，世界！这是一个测试。");
    
    // Create a sentence break iterator
    std::unique_ptr<icu::BreakIterator> sentenceIterator(
        icu::BreakIterator::createSentenceInstance(icu::Locale::getUS(), status)
    );
    
    if (U_FAILURE(status)) {
        println("Error creating sentence iterator: {}", u_errorName(status));
        return;
    }
    
    sentenceIterator->setText(text);
    
    // Iterate through sentences
    println("Sentence boundaries:");
    int32_t start = sentenceIterator->first();
    int32_t end   = sentenceIterator->next();
    int sentenceCount = 1;
    
    while (end != icu::BreakIterator::DONE) {
        icu::UnicodeString sentence = text.tempSubString(start, end - start);
        println("  Sentence {}", sentenceCount++);
        println("    {}",        toString(sentence));
        start = end;
        end = sentenceIterator->next();
    }
    
    // Create a word break iterator
    status = U_ZERO_ERROR;
    std::unique_ptr<icu::BreakIterator> wordIterator(
        icu::BreakIterator::createWordInstance(icu::Locale::getUS(), status)
    );
    
    if (U_FAILURE(status)) {
        println("Error creating word iterator: {}", u_errorName(status));
        return;
    }
    
    // Just count words in the first sentence
    icu::UnicodeString firstSentence = text.tempSubString(0, text.indexOf(".") + 1);
    wordIterator->setText(firstSentence);
    
    int wordCount = 0;
    start = wordIterator->first();
    while ((end = wordIterator->next()) != icu::BreakIterator::DONE) {
        icu::UnicodeString word = firstSentence.tempSubString(start, end - start);
        // Skip punctuation and whitespace
        if (word.trim().length() > 0 && !u_ispunct(word.char32At(0))) {
            wordCount++;
        }
        start = end;
    }
    
    println("Words in first sentence: {}", wordCount);
}
    
// Example 4: Transliteration
void runTransliterationExample() {
    println("\n=== Running Transliteration Example ===");
    
    // Helper function to convert UnicodeString to std::string for output
    auto toString = [](const icu::UnicodeString& ustr) -> std::string {
        std::string result;
        ustr.toUTF8String(result);
        return result;
    };
    
    UErrorCode status = U_ZERO_ERROR;
    
    // Create a transliterator for Latin to Cyrillic
    std::unique_ptr<icu::Transliterator> latinToCyrillic(
        icu::Transliterator::createInstance("Latin-Cyrillic", UTRANS_FORWARD, status)
    );
    
    if (U_FAILURE(status)) {
        println("Error creating transliterator: {}", u_errorName(status));
        return;
    }
    
    // Transliterate some text
    icu::UnicodeString latinText = icu::UnicodeString::fromUTF8("Privet, mir! Kak dela?");
    println("Original text: {}", toString(latinText));
    
    latinToCyrillic->transliterate(latinText);
    println("Transliterated to Cyrillic: {}", toString(latinText));
    
    // Create a transliterator for Cyrillic to Latin
    status = U_ZERO_ERROR;
    std::unique_ptr<icu::Transliterator> cyrillicToLatin(
        icu::Transliterator::createInstance("Cyrillic-Latin", UTRANS_FORWARD, status)
    );
    
    if (U_FAILURE(status)) {
        println("Error creating reverse transliterator: {}", u_errorName(status));
        return;
    }
    
    cyrillicToLatin->transliterate(latinText);
    println("Transliterated back to Latin: {}", toString(latinText));
}


// Example 5: ICU Data Bundle Verification
void testICUDataBundle() {
    std::cout << "\n=== ICU Data Bundle Verification ===" << std::endl;
    
    // Helper function to convert UnicodeString to std::string for output
    auto toString = [](const icu::UnicodeString& ustr) -> std::string {
        std::string result;
        ustr.toUTF8String(result);
        return result;
    };
    
    bool allTestsPassed = true;
    UErrorCode status = U_ZERO_ERROR;
    
    // Test 1: Check if we can access character properties (requires uchar.dat)
    println("1. Testing character properties data...");
    UChar32 testChar = 0x0041;  // Latin 'A'
    int charType = u_charType(testChar);
    if (charType == U_UPPERCASE_LETTER) {
        println("   ✅ Character properties data accessible");
    } else {
        println("   ❌ Character properties data not working correctly");
        allTestsPassed = false;
    }
    
    // Test 2: Check if we can access collation data (requires coll.dat)
    println("2. Testing collation data...");
    status = U_ZERO_ERROR;
    std::unique_ptr<icu::Collator> coll(icu::Collator::createInstance(icu::Locale::getUS(), status));
    if (U_SUCCESS(status)) {
        println("   ✅ Collation data accessible");
        
        // Test basic collation functionality
        icu::UnicodeString str1 = icu::UnicodeString::fromUTF8("apple");
        icu::UnicodeString str2 = icu::UnicodeString::fromUTF8("banana");
        icu::Collator::EComparisonResult result = coll->compare(str1, str2);
        
        if (result == icu::Collator::LESS) {
            println("   ✅ Collation comparison works correctly");
        } else {
            println("   ❌ Collation comparison failed");
            allTestsPassed = false;
        }
    } else {
        println("   ❌ Failed to access collation data: {}", u_errorName(status));
        allTestsPassed = false;
    }
    
    // Test 3: Check if we can access calendar data (requires ucal.dat)
    println("3. Testing calendar data...");
    status = U_ZERO_ERROR;
    std::unique_ptr<icu::Calendar> cal(icu::Calendar::createInstance(icu::Locale("ja_JP@calendar=japanese"), status));
    if (U_SUCCESS(status)) {
        println("   ✅ Calendar data accessible");
        
        // Test basic calendar functionality
        int32_t year  = cal->get(UCAL_YEAR, status);
        int32_t month = cal->get(UCAL_MONTH, status) + 1; // 0-based to 1-based
        int32_t day   = cal->get(UCAL_DATE, status);
        int32_t era   = cal->get(UCAL_ERA, status);
        
        if (U_SUCCESS(status)) {
            println("   ✅ Japanese calendar date: Era {}, Year {}, Month {}, Day {}", era, year, month, day);
        } else {
            println("   ❌ Failed to get calendar fields: {}", u_errorName(status));
            allTestsPassed = false;
        }
    } else {
        println("   ❌ Failed to create Japanese calendar: {}", u_errorName(status));
        allTestsPassed = false;
    }
    
    // Test 4: Check if we can access resource bundle data (requires res files)
    println("4. Testing resource bundle data...");
    status = U_ZERO_ERROR;
    
    // Try to open the ICU data file directly
    UDataMemory* data = udata_open(nullptr, "dat", "icudt77l", &status);
    if (U_SUCCESS(status)) {
        std::cout << "   ✅ ICU data file accessible" << std::endl;
        udata_close(data);
    } else {
        // Try alternative approach - check if we can get locale display names
        status = U_ZERO_ERROR;
        icu::Locale locale("en_US");
        icu::UnicodeString displayName;
        locale.getDisplayName(displayName);
        
        if (displayName.length() > 0) {
            println("   ✅ Resource data accessible (via locale display names)");
        } else {
            println("   ❌ Failed to access resource data: {}", u_errorName(status));
            allTestsPassed = false;
        }
    }
    
    // Test 5: Check if we can access converter data (requires cnv files)
    println("5. Testing converter data...");
    status = U_ZERO_ERROR;
    UConverter* conv = ucnv_open("Shift-JIS", &status);
    if (U_SUCCESS(status)) {
        println("   ✅ Converter data accessible");
        ucnv_close(conv);
    } else {
        println("   ❌ Failed to open converter: {}", u_errorName(status));
        allTestsPassed = false;
    }
    
    // Summary
    println("\nICU Data Bundle Verification Summary:");
    if (allTestsPassed) {
        println("✅ All ICU data tests passed! The data bundle is properly included and accessible.");
    } else {
        println("❌ Some ICU data tests failed. The data bundle may not be properly included or accessible.");
    }
}

int main() {
    // Print ICU version
    println("ICU Version: {}", U_ICU_VERSION);

    // Run the string example
    runStringExample();
    runLocaleExample();
    runBreakIteratorExample();
    runTransliterationExample();

    println("ICU4C test completed successfully!");
    return 0;
}
