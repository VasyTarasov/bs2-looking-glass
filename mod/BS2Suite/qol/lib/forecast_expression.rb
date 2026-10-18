# encoding: UTF-8
module BS2QoL
  module Forecast
    class Unsupported < StandardError;end
    # A closed arithmetic language, not Ruby eval. Both branches are parsed, only
    # the selected ternary branch is computed. Integer division remains Ruby 1.9's.
    class Expression
      STATS=%w[hp mp tp mhp mmp atk def mat mdf agi luk level hp_rate mp_rate mcr rec pha hit eva mev cri cev cnt mrf grd pdr mdr].freeze
      def initialize(source)
        raise Unsupported,'expression too long' if source.to_s.bytesize>1024
        @source=source.to_s;@tokens=[];pos=0
        while pos<@source.size
          match=/\G\s*(\d+(?:\.\d+)?|[A-Za-z_][A-Za-z_0-9]*\??|<=|>=|==|!=|[+\-*\/%().,\[\]?:<>])/.match(@source,pos)
          if !match
            break if @source[pos,@source.size].strip.empty?
            raise Unsupported,'unrecognized expression syntax'
          end
          @tokens << match[1];pos=match.end(0)
          raise Unsupported,'too many tokens' if @tokens.size>256
        end
        @index=0;@depth=0
        @tree=@tokens.empty? ? [:number,0] : parse
        raise Unsupported,'trailing tokens' if peek
      end
      def peek;@tokens[@index];end
      def take;value=peek;@index+=1;value;end
      def expect(token);raise Unsupported,'expected '+token unless take==token;end
      def parse(minimum=0)
        @depth+=1;raise Unsupported,'expression nesting too deep' if @depth>32
        token=take
        left=case token
        when '+','-';[:unary,token,parse(40)]
        when '(';value=parse;expect(')');value
        when '['
          array=[parse]
          while peek==',';take;array<<parse;raise Unsupported,'array too long' if array.size>8;end
          expect(']');expect('.');operation=take
          raise Unsupported,'only array min/max is supported' unless ['min','max'].include?(operation)
          [:array,operation,array]
        when 'a','b','user'
          expect('.');stat=take
          if stat=='state?'
            expect('(');id=parse;expect(')');[:state,token,id]
          else
            raise Unsupported,'unrecognized stat' unless STATS.include?(stat)
            [:stat,token,stat]
          end
        when 'v'
          expect('[');id=parse;expect(']');[:variable,id]
        else
          raise Unsupported,'number or known reference required' unless token && /\A\d+(?:\.\d+)?\z/=~token
          [:number,token.include?('.') ? token.to_f : token.to_i]
        end
        precedence={'*'=>30,'/'=>30,'%'=>30,'+'=>20,'-'=>20,'<'=>10,'>'=>10,'<='=>10,'>='=>10,'=='=>10,'!='=>10}
        while (power=precedence[peek]) && power>=minimum
          operation=take;right=parse(power+1);left=[:binary,operation,left,right]
        end
        if minimum==0 && peek=='?'
          take;yes=parse;expect(':');no=parse;left=[:condition,left,yes,no]
        end
        @depth-=1;left
      end
      def value(a,b,variables=nil)
        @steps=0
        compute(@tree,{'a'=>a,'user'=>a,'b'=>b},variables)
      end
      def numeric(value)
        raise Unsupported,'non-numeric or excessive value' unless value.is_a?(Numeric) && value.abs<=1.0e15
        value
      end
      def compute(node,objects,variables)
        @steps+=1;raise Unsupported,'expression budget exceeded' if @steps>512
        case node[0]
        when :number;node[1]
        when :stat
          object=objects[node[1]];raise Unsupported,'missing expression user' unless object
          numeric(object.values.fetch(node[2]))
        when :state
          object=objects[node[1]];raise Unsupported,'missing state user' unless object
          object.states.include?(numeric(compute(node[2],objects,variables)).to_i)
        when :variable
          id=numeric(compute(node[1],objects,variables)).to_i
          raise Unsupported,'invalid variable ID' unless id>=0 && id<100000
          numeric(variables ? variables[id] : 0)
        when :unary
          value=numeric(compute(node[2],objects,variables));node[1]=='-' ? -value : value
        when :array
          values=node[2].map { |child| numeric(compute(child,objects,variables)) }
          node[1]=='min' ? values.min : values.max
        when :condition
          condition=compute(node[1],objects,variables)
          compute(condition.nil? || condition==false ? node[3] : node[2],objects,variables)
        when :binary
          left=numeric(compute(node[2],objects,variables));right=numeric(compute(node[3],objects,variables))
          case node[1]
          when '+';numeric(left+right)
          when '-';numeric(left-right)
          when '*';numeric(left*right)
          when '/';numeric(left/right)
          when '%';numeric(left%right)
          when '<';left<right
          when '>';left>right
          when '<=';left<=right
          when '>=';left>=right
          when '==';left==right
          when '!=';left!=right
          end
        end
      end
    end
    class << self
      def expression(source,a,b)
        @expressions||={};@expressions.clear if @expressions.size>512
        ast=@expressions[source] ||= Expression.new(source)
        ast.value(a,b,$game_variables)
      end
    end
  end
end
