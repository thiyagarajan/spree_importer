require 'spec_helper'

describe SpreeImporter::Exporter do
  before :each do
    @product = FactoryGirl.create :product_with_option_types, sku: "FNORD"
    FactoryGirl.create :option_value, option_type: @product.option_types.first
    FactoryGirl.create :property, name: "fnordprop", presentation: "fnordprop"
    @product.option_types << FactoryGirl.create(:option_type,
                                                name: "fnord",
                                                presentation: "Gregg",
                                                option_values: [
                FactoryGirl.build(:option_value, position: 1, name: "Fnord", presentation: "F"),
                FactoryGirl.build(:option_value, position: 2,name: "Skidoo", presentation: "S")
             ])
    @product.set_property "fnordprop", "fliff"
    @headers = %w| sku name price available_on description meta_description meta_keywords cost_price
                   [option](foo-size)Size [option](fnord)Gregg [property]fnordprop |
  end

  it "should return the correct kind of exporters" do
    exporter = SpreeImporter::Exporter.new
    exporter.get_exporters(nil).map(&:class).should_not include(SpreeImporter::Exporters::Variant)
    exporter.variant_export!
    exporter.get_exporters(nil).map(&:class).should_not include(SpreeImporter::Exporters::Product)
  end

  it "should generate headers" do
    exporter = SpreeImporter::Exporter.new
    string   = exporter.export
    @headers.should == exporter.headers
  end

  it "should find shit" do
    FactoryGirl.create :product_with_option_types, sku: "MOTH_ER_LICK_ER"
    exporter = SpreeImporter::Exporter.new
    csv      = CSV.new exporter.export(search: { variants_including_master_sku_cont: "MOTH"}), headers: true
    rows     = csv.read
    rows.length.should eql 1
  end

  it "should generate mothafuckin' rows" do
    exporter = SpreeImporter::Exporter.new
    csv_text = exporter.export
    csv      = CSV.parse csv_text, headers: true
    sku      = @product.sku
    csv.inject(0) { |acc| acc + 1 }.should eql 1

    [ Spree::Variant, Spree::Product, Spree::Property, Spree::OptionType ].each &:destroy_all

    importer = Spree::ImportSourceFile.new data: csv_text

    importer.import!

    product = Spree::Product.first

    product.option_types.length.should eql 2

    fnord   = product.option_types.select{|ot| ot.name == "fnord" }.first

    fnord.should_not be_nil

    fval    = fnord.option_values.find_by_name "Fnord"

    fval.presentation.should eql "F"
    product.property("fnordprop").should eql "fliff"
    product.sku.should eql sku
  end

  it "should export an empty template file" do
    [ Spree::Product, Spree::Property, Spree::OptionType ].each &:destroy_all
    dummeh   = SpreeImporter::DummyProduct.new
    exporter = SpreeImporter::Exporter.new
    csv_text = exporter.export search: :dummy
    csv      = CSV.new csv_text, headers: true
    rows     = csv.read
    csv.rewind

    row      = csv.gets

    rows.length.should eql 1
    row.headers.length.should eql 10

    %w[ sku name price description meta_description
        meta_keywords cost_price ].each do |header|
      row[header].should eql dummeh.send(header).to_s
    end

    row["[option](option_type)Option Type"].should eql "(option1)O1,(option2)O2"
    row["[property](property_name)Property Name"].should eql "Property Value"
  end

  it "should export variants instead of products" do
    options = Spree::OptionType.all
    FactoryGirl.create :option_value
    @product.option_values_hash = options.inject({}) do |acc, opt|
      acc[opt.id] = opt.option_values.map &:id unless opt.option_values.empty?
      acc
    end

    @product.send :build_variants_from_option_values_hash
    @product.variants.each &:generate_sku!

    count = 0
    @product.variants.each do |v|
      v.stock_items.first.update_column :count_on_hand, (count+=1)
    end

    exporter = SpreeImporter::Exporter.new
    csv_text = exporter.export variants: true
    csv      = CSV.new csv_text, headers: true
    rows     = csv.read

    csv.rewind
    rows.length.should eql 2

    first_row = csv.gets

    first_row["master_sku"].should_not be_nil
    first_row["(default)quantity"].should eql "1"
  end
end